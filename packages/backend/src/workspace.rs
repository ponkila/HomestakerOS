use anyhow::{Context, Result};
use std::fs;
use std::path::PathBuf;
use tempfile::TempDir;
use uuid::Uuid;

/// Top-level workspace.
pub struct Workspace {
    pub base_dir: TempDir,
}

/// A build-specific workspace.
pub struct Build {
    pub uuid: String,
    pub working_dir: PathBuf,
    pub nix_config_dir: PathBuf,
    pub hostname_dir: PathBuf,
    pub out_link: PathBuf,
    pub output_dir: PathBuf,
}

impl Workspace {
    /// Create a new top-level workspace.
    ///
    /// # Errors
    ///
    /// Returns an error if a temporary directory cannot be created or if the builds directory cannot be created.
    pub fn new() -> Result<Self> {
        let base_dir = TempDir::new().context("Failed to create temporary directory")?;
        fs::create_dir_all(base_dir.path().join("builds"))
            .with_context(|| format!("Failed to create builds directory at {base_dir:?}/builds"))?;
        Ok(Workspace { base_dir })
    }

    /// Create a new build-specific workspace.
    ///
    /// # Errors
    ///
    /// Returns an error if any of the required directories cannot be created.
    pub fn new_build_workspace(&self, hostname: &str) -> Result<Build> {
        let build_uuid = Uuid::new_v4().to_string();
        let dir_name = "build_work_".to_string() + &build_uuid;
        let working_dir = self.base_dir.path().join(dir_name);

        // Create the directories.
        fs::create_dir_all(&working_dir)
            .with_context(|| format!("Failed to create working directory at {working_dir:?}"))?;
        let nix_config_dir = working_dir.join("nixConfig");
        fs::create_dir_all(&nix_config_dir).with_context(|| {
            format!("Failed to create nix config directory at {nix_config_dir:?}")
        })?;
        let hostname_dir = nix_config_dir.join("nixosConfigurations").join(hostname);
        fs::create_dir_all(&hostname_dir)
            .with_context(|| format!("Failed to create hostname directory at {hostname_dir:?}"))?;

        // Construct a path for the nix build result.
        let out_link = working_dir.join("kexecTree");

        // Create the final build directory.
        let output_dir = self.base_dir.path().join("builds").join(&build_uuid);
        fs::create_dir_all(&output_dir)
            .with_context(|| format!("Failed to create output directory at {output_dir:?}"))?;

        Ok(Build {
            uuid: build_uuid,
            working_dir,
            nix_config_dir,
            hostname_dir,
            out_link,
            output_dir,
        })
    }
}

/// Automatic partial cleanup.
impl Drop for Build {
    fn drop(&mut self) {
        if self.working_dir.exists() {
            if let Err(e) = fs::remove_dir_all(&self.working_dir) {
                eprintln!("Warning: Failed to remove working_dir: {e:?}");
            }
        }
    }
}
