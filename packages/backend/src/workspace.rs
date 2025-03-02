use std::fs;
use std::io;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

/// Encapsulates the build workspace directories.
pub struct BuildWorkspace {
    pub working_dir: PathBuf,
    pub nix_config_dir: PathBuf,
    pub hostname_dir: PathBuf,
    pub out_link: PathBuf,
}

impl BuildWorkspace {
    /// Creates a new workspace with a unique working directory.
    pub fn new(output_dir: &Path, hostname: &str) -> io::Result<Self> {
        let unique_id = match SystemTime::now().duration_since(UNIX_EPOCH) {
            Ok(duration) => duration.as_nanos().to_string(),
            Err(_) => "default".to_string(),
        };
        let mut dir_name = String::with_capacity("build_work_".len() + unique_id.len());
        dir_name.push_str("build_work_");
        dir_name.push_str(&unique_id);
        let working_dir = output_dir.join(dir_name);

        // Create the directories.
        fs::create_dir_all(&working_dir)?;
        let nix_config_dir = working_dir.join("nixConfig");
        fs::create_dir_all(&nix_config_dir)?;
        let hostname_dir = nix_config_dir.join("nixosConfigurations").join(hostname);
        fs::create_dir_all(&hostname_dir)?;

        // Construct a path for the nix build result.
        let out_link = working_dir.join("kexecTree");

        Ok(BuildWorkspace {
            working_dir,
            nix_config_dir,
            hostname_dir,
            out_link,
        })
    }

    /// Cleans up the original directories.
    pub fn cleanup(&self) -> io::Result<()> {
        fs::remove_dir_all(&self.nix_config_dir)?;
        fs::remove_file(&self.out_link)?;
        Ok(())
    }
}
