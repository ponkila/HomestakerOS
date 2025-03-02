use std::fs;
use std::io;
use std::path::PathBuf;
use tempfile::TempDir;
use uuid::Uuid;

pub struct Workspace {
    pub base_dir: TempDir,
}

pub struct BuildWorkspace {
    pub uuid: String,
    pub working_dir: PathBuf,
    pub nix_config_dir: PathBuf,
    pub hostname_dir: PathBuf,
    pub out_link: PathBuf,
}

impl Workspace {
    /// Create a new top-level workspace.
    pub fn new() -> io::Result<Self> {
        let base_dir = TempDir::new()?;
        fs::create_dir_all(base_dir.path().join("builds"))?;
        Ok(Workspace { base_dir })
    }

    /// Create a new build-specific workspace.
    pub fn new_build_workspace(&self, hostname: &str) -> io::Result<BuildWorkspace> {
        let build_uuid = Uuid::new_v4().to_string();
        let dir_name = "build_work_".to_string() + &build_uuid;
        let working_dir = self.base_dir.path().join(dir_name);

        // Create the directories.
        fs::create_dir_all(&working_dir)?;
        let nix_config_dir = working_dir.join("nixConfig");
        fs::create_dir_all(&nix_config_dir)?;
        let hostname_dir = nix_config_dir.join("nixosConfigurations").join(hostname);
        fs::create_dir_all(&hostname_dir)?;

        // Construct a path for the nix build result.
        let out_link = working_dir.join("kexecTree");

        Ok(BuildWorkspace {
            uuid: build_uuid,
            working_dir,
            nix_config_dir,
            hostname_dir,
            out_link,
        })
    }
}

/// Automatic partial cleanup
impl Drop for BuildWorkspace {
    fn drop(&mut self) {
        if self.working_dir.exists() {
            if let Err(e) = fs::remove_dir_all(&self.working_dir) {
                eprintln!("Warning: Failed to remove working_dir: {:?}", e);
            }
        }
    }
}
