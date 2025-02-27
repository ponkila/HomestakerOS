use backend::workspace::BuildWorkspace;
use std::fs;
use tempfile::TempDir;

#[test]
fn test_build_workspace_creation() -> Result<(), Box<dyn std::error::Error>> {
    let temp_dir = TempDir::new()?;
    let output_dir = temp_dir.path();
    let hostname = "testhost";

    let workspace = BuildWorkspace::new(output_dir, hostname)?;

    // Verify that the directories exist.
    assert!(workspace.working_dir.exists());
    assert!(workspace.nix_config_dir.exists());
    assert!(workspace.hostname_dir.exists());

    Ok(())
}

#[test]
fn test_cleanup() -> Result<(), Box<dyn std::error::Error>> {
    let temp_dir = TempDir::new()?;
    let output_dir = temp_dir.path();
    let hostname = "testhost";

    let workspace = BuildWorkspace::new(output_dir, hostname)?;

    // Create a dummy file at out_link to simulate a generated file.
    fs::write(&workspace.out_link, "dummy")?;

    // Call cleanup to remove the directories.
    workspace.cleanup()?;

    // Verify that the directories and file have been removed.
    assert!(!workspace.nix_config_dir.exists());
    assert!(!workspace.out_link.exists());

    Ok(())
}
