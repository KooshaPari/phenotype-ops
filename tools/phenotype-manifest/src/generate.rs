//! Manifest generation logic
use crate::cli::GenerateArgs;
use crate::crypto::{load_signing_key, sign_manifest};
use crate::manifest::{Manifest, PillarResult, Pillars};
use crate::pillar::{run_pillar_checks, Pillar};
use anyhow::{anyhow, Result};
use chrono::{Duration, Utc};
use git2::Repository;
use std::collections::HashMap;
use std::fs;
use std::path::Path;
use std::time::Instant;
use tracing::{info, warn};

pub fn generate_manifest(args: GenerateArgs) -> Result<()> {
    info!("Generating attestation manifest...");
    let repo = Repository::discover(".")?;
    let head = repo.head()?.peel_to_commit()?;
    let commit_sha = head.id().to_string();
    let tree_sha = head.tree_id().to_string();
    info!("Commit: {}", &commit_sha[..12]);
    info!("Tree:   {}", &tree_sha[..12]);

    let key_path_str = args.key.to_string_lossy().to_string();
    let key_path_str = if let Some(stripped) = key_path_str.strip_prefix("~/") {
        let home = std::env::var("HOME").unwrap_or_else(|_| ".".to_string());
        format!("{}/{}", home, stripped)
    } else {
        key_path_str
    };
    let signing_key = load_signing_key(Path::new(&key_path_str))?;

    let all_pillars = [Pillar::Quality, Pillar::Security, Pillar::Perf, Pillar::Compliance, Pillar::Docs];
    let skip: std::collections::HashSet<String> = args.skip_pillars.iter().cloned().collect();
    let pillars_to_run: Vec<Pillar> = all_pillars
        .into_iter()
        .filter(|p| !skip.contains(&p.to_string()))
        .collect();

    let mut pillar_results = Pillars {
        quality: PillarResult::default(),
        security: PillarResult::default(),
        perf: PillarResult::default(),
        compliance: PillarResult::default(),
        docs: PillarResult::default(),
    };

    let mut total_checks = 0;
    let mut passed_checks = 0;
    for pillar in &pillars_to_run {
        info!("Running pillar: {}", pillar);
        let start = Instant::now();
        let result = run_pillar_checks(*pillar)?;
        let duration = start.elapsed().as_millis() as u64;
        let passed = result.checks.values().filter(|c| c.passed).count();
        let total = result.checks.len();
        total_checks += total;
        passed_checks += passed;
        match pillar {
            Pillar::Quality => pillar_results.quality = result,
            Pillar::Security => pillar_results.security = result,
            Pillar::Perf => pillar_results.perf = result,
            Pillar::Compliance => pillar_results.compliance = result,
            Pillar::Docs => pillar_results.docs = result,
        }
        info!("  {} checks, {} passed, {}ms", total, passed, duration);
    }
    for pillar in &all_pillars {
        if skip.contains(&pillar.to_string()) {
            let result = PillarResult {
                passed: true,
                checks: HashMap::new(),
                duration_ms: 0,
                skip_reason: Some("Skipped by user".into()),
            };
            match pillar {
                Pillar::Quality => pillar_results.quality = result,
                Pillar::Security => pillar_results.security = result,
                Pillar::Perf => pillar_results.perf = result,
                Pillar::Compliance => pillar_results.compliance = result,
                Pillar::Docs => pillar_results.docs = result,
            }
        }
    }
    let health_score = if total_checks > 0 {
        passed_checks as f64 / total_checks as f64
    } else { 1.0 };
    if health_score < args.fail_below {
        warn!("Health score {:.2} below threshold {:.2}", health_score, args.fail_below);
    }
    let now = Utc::now();
    let mut manifest = Manifest {
        schema_version: crate::manifest::MANIFEST_SCHEMA_VERSION,
        generated_at: now,
        commit_sha,
        tree_sha,
        pillars: pillar_results,
        health_score,
        expires_at: now + Duration::hours(args.max_age_hours as i64),
        signature: String::new(),
        public_key: String::new(),
        generator: Some(crate::manifest::GeneratorInfo {
            name: "phenotype-manifest".into(),
            version: env!("CARGO_PKG_VERSION").into(),
            rustc_version: option_env!("RUSTC_VERSION").unwrap_or("unknown").into(),
            platform: std::env::consts::OS.into(),
        }),
    };
    sign_manifest(&mut manifest, &signing_key)?;
    let json = serde_json::to_string_pretty(&manifest)?;
    if args.stdout {
        println!("{}", json);
    } else {
        fs::write(&args.output, json)?;
        info!("Manifest written to {}", args.output.display());
    }
    if args.human {
        println!("\n{}", manifest.format_human());
        println!("\nHealth score: {:.1}% {}", health_score * 100.0, if health_score >= args.fail_below { "PASS" } else { "FAIL" });
    }
    if health_score < args.fail_below {
        return Err(anyhow!("Health score below threshold"));
    }
    Ok(())
}

impl Default for PillarResult {
    fn default() -> Self {
        Self { passed: true, checks: HashMap::new(), duration_ms: 0, skip_reason: None }
    }
}
