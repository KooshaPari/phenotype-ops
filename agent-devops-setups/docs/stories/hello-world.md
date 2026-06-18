# Hello World

<StoryHeader
    title="First Operation"
    duration="2"
    difficulty="beginner"
/>

## Objective

Run your first agent-devops-setups operation.

## Implementation

```rust
use agent_devops_setups::Client;

#[tokio::main]
async fn main() {
    let client = Client::new().await.unwrap();
    let result = client.hello().await.unwrap();
    println!("{}", result);
}
```

## Output

```
Hello from agent-devops-setups!
```
