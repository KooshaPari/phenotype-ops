//! phenotype-manifest — Attestation manifest generator and validator
use clap::{Parser, Subcommand};
use std::path::PathBuf;

use phenotype_manifest::cli::{GenerateArgs, ShowArgs, VerifyArgs};
use phenotype_manifest::crypto::{generate_keypair, save_keypair};
use phenotype_manifest::generate::generate_manifest;
use phenotype_manifest::manifest::Manifest;
use phenotype_manifest::pillar::Pillar;
use phenotype_manifest::schema::validate_manifest;
use phenotype_manifest::verify::verify_manifest_cmd as verify_manifest;

#[derive(Parser)]
#[command(name = "phenotype-manifest", version, about, long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
    #[arg(short, long, global = true)]
    verbose: bool,
}

#[derive(Subcommand)]
enum Commands {
    Generate(GenerateArgs),
    Verify(VerifyArgs),
    Show(ShowArgs),
    RunPillar {
        pillar: String,
        #[arg(short, long, default_value = "human")]
        format: String,
    },
    Init {
        #[arg(long, default_value = "~/.ssh/manifest")]
        key: PathBuf,
        #[arg(long)]
        generate_key: bool,
    },
}

fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();
    if cli.verbose {
        tracing_subscriber::fmt().with_env_filter("debug").init();
    } else {
        tracing_subscriber::fmt().with_env_filter("info").init();
    }
    match cli.command {
        Commands::Generate(args) => generate_manifest(args),
        Commands::Verify(args) => verify_manifest(args),
        Commands::Show(args) => show_manifest(args),
        Commands::RunPillar { pillar, format } => run_pillar(&pillar, &format),
        Commands::Init { key, generate_key } => init_repo(key, generate_key),
    }
}

fn show_manifest(args: ShowArgs) -> anyhow::Result<()> {
    let content = std::fs::read_to_string(&args.manifest)?;
    let json: serde_json::Value = serde_json::from_str(&content)?;
    validate_manifest(&json).map_err(|errs| anyhow::anyhow!(errs.join("; ")))?;
    let manifest: Manifest = serde_json::from_value(json)?;
    if args.json {
        println!("{}", serde_json::to_string_pretty(&manifest)?);
    } else {
        println!("{}", manifest.format_human());
    }
    Ok(())
}

fn run_pillar(pillar: &str, format: &str) -> anyhow::Result<()> {
    let pillar_enum = pillar.parse::<Pillar>()?;
    let result = pillar_enum.run_checks()?;
    if format == "json" {
        println!("{}", serde_json::to_string_pretty(&result)?);
    } else {
        println!("Pillar {}: {} ({} ms)", pillar_enum, if result.passed { "PASS" } else { "FAIL" }, result.duration_ms);
        for (name, check) in &result.checks {
            println!("  {} {} ({} ms)", if check.passed { "[OK]" } else { "[FAIL]" }, name, check.duration_ms);
        }
    }
    Ok(())
}

fn init_repo(key_path: PathBuf, generate_key: bool) -> anyhow::Result<()> {
    use std::os::unix::fs::PermissionsExt;

    // Expand tilde
    let key_path_str = key_path.to_string_lossy().to_string();
    let key_path_str = if let Some(stripped) = key_path_str.strip_prefix("~/") {
        let home = std::env::var("HOME").unwrap_or_else(|_| ".".to_string());
        format!("{}/{}", home, stripped)
    } else {
        key_path_str
    };
    let key_path = PathBuf::from(key_path_str);

    if generate_key || !key_path.exists() {
        println!("Generating Ed25519 key at {}", key_path.display());
        let (signing_key, verifying_key) = generate_keypair();
        std::fs::create_dir_all(key_path.parent().unwrap())?;
        let pubkey_path = key_path.with_extension("pub");
        save_keypair(&signing_key, &verifying_key, &key_path, &pubkey_path)?;
        std::fs::set_permissions(&key_path, std::fs::Permissions::from_mode(0o600))?;
        println!("Key pair generated: {} + {}", key_path.display(), pubkey_path.display());
    }

    // Copy lefthook.yml from phenotype-ops governance
    let lefthook_src = std::env::current_dir()?.join("../../governance/lefthook.yml");
    let lefthook_dst = std::env::current_dir()?.join("lefthook.yml");
    if lefthook_src.exists() {
        std::fs::copy(&lefthook_src, &lefthook_dst)?;
        println!("Copied lefthook.yml from {}", lefthook_src.display());
    } else {
        println!("lefthook template not found at {}; please copy manually", lefthook_src.display());
    }

    println!("Next steps:");
    println!("   1. lefthook install");
    println!("   2. Add public key to .github/manifest.pubkey.pem");
    println!("   3. git push (will generate manifest)");
    Ok(())
}
