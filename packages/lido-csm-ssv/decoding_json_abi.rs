use alloy::{primitives::hex, sol};
use alloy_sol_types::SolEvent;
use std::io;
use serde::{Deserialize, Serialize};

sol!(
  #[derive(Serialize, Deserialize, Debug)]
  SSVNetwork,
  "SSVNetwork.json"
);

fn main() {
    io::stdin().lines()
      .map(|v| v.unwrap())
      .map(|v| hex::decode(v).unwrap())
      .map(|v| SSVNetwork::ValidatorAdded::abi_decode_data(&v, true).unwrap())
      .for_each(|v| println!("{}", serde_json::to_string(&v).unwrap()));
}
