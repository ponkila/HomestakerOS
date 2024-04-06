import * as O from 'fp-ts/Option'
import { pipe } from 'fp-ts/function'
import {
  Alert,
  AlertIcon,
  AlertStatus,
  Spinner,
} from '@chakra-ui/react'
import { BlockResponse } from '../App'

export const StatusPage = (props: any) => {

  const nodes = props.nodes ? <Alert status='success'>
    <AlertIcon />
    {props.nodes.length} nodes loaded:
    {props.nodes.map((v: Record<string, any>) => (
      <details>
        <summary>{v.localization.hostname}</summary>
        <code>{JSON.stringify(v)}</code>
      </details>
    ))}
  </Alert> : <Alert status='info'>
    <AlertIcon />
    No nodes
  </Alert>

  const backend = props.backend ? <Alert status='success'>
    <AlertIcon />
    Backend: ok, NixOS building enabled
  </Alert> : <Alert status='warning'>
    <AlertIcon />
    Backend disabled, entering demo mode: NixOS building disabled.
  </Alert>

  const schema = pipe(
    props.count,
    O.match(
      () =>
        <Alert status='error'>
          <AlertIcon />
          Schema: could not find schema, NixOS configuration tab is disabled. To fix this, run <code>nix eval --no-warn-dirty --json .#schema | jq {'>'} webui/public/schema.json</code> in the project root folder.
        </Alert>
      ,
      (head) =>
        <Alert status='success'>
          <AlertIcon />
          <details>
            <summary>Schema loaded, NixOS configuration enabled</summary>
            <code>{JSON.stringify(head)}</code>
          </details>
        </Alert>
    )
  )

  const blocks = props.blocks ? props.blocks.map((x: BlockResponse) => {
    const status: AlertStatus = pipe(x.data, O.match(
      () => "error",
      (x) => x.execution_optimistic ? "warning" : "success",
    ))
    const message: string = pipe(x.data, O.match(
      () => "Could not connect to JSON-RPC endpoint. Is your VPN connection to this node online?",
      (x) => `${x.execution_optimistic ? "Node is online but optimistic" : "Node OK"}`,
    ))
    const body = pipe(x.data, O.match(
      () => <>{x.host}: {message}</>,
      (data) => <details><summary>{x.host}: {message}</summary><code>{JSON.stringify(data)}</code></details>,
    ))
    return (
      <Alert status={status}>
        <AlertIcon />
        {body}
      </Alert>
    )
  }) : <Alert status="info"><AlertIcon />Loading node statuses... <Spinner /></Alert>

  return (
    <>
      {schema}
      {backend}
      {nodes}
      {blocks}
    </>
  )
}

