import * as O from 'fp-ts/Option'
import { pipe } from 'fp-ts/function'
import {
  Alert,
  AlertIcon,
} from '@chakra-ui/react'

export const StatusPage = (props: any) => {

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

  return (
    <>
      {schema}
      {backend}
    </>
  )
}

