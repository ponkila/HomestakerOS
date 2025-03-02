use backend::workspace::Workspace;

#[test]
fn test_global_workspace_creation() -> Result<(), Box<dyn std::error::Error>> {
    let workspace = Workspace::new()?;

    // Verify that the workspace directories exists.
    assert!(workspace.base_dir.path().exists());
    assert!(workspace.base_dir.path().join("builds").exists());

    Ok(())
}

#[test]
fn test_build_workspace_creation() -> Result<(), Box<dyn std::error::Error>> {
    let workspace = Workspace::new()?;
    let hostname = "testhost";

    // Create the sub-workspace.
    let build_ws = workspace.new_build_workspace(hostname)?;

    // Verify that the sub-workspace directories exist.
    assert!(build_ws.working_dir.exists());
    assert!(build_ws.nix_config_dir.exists());
    assert!(build_ws.hostname_dir.exists());

    // For now, out_link path should't exist.
    assert!(!build_ws.out_link.exists());

    Ok(())
}

#[test]
fn test_cleanup() -> Result<(), Box<dyn std::error::Error>> {
    let workspace = Workspace::new()?;
    let hostname = "testhost";

    // Create the sub-workspace
    let build_ws = workspace.new_build_workspace(hostname)?;

    // Clone the path for later inspection.
    let working_dir = build_ws.working_dir.clone();

    // Drop the build workspace to trigger the cleanup.
    drop(build_ws);

    // Verify that the directorie have been removed.
    assert!(!working_dir.exists());

    Ok(())
}
