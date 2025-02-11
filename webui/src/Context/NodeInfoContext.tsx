import { useContext, createContext } from 'react'
import * as O from 'fp-ts/Option'
import { useLoaderData } from 'react-router-dom'

export const fetchHostnames = async (flake: string): Promise<string[]> => {
  const uri = `${flake}/nixosConfigurations/hostnames.json`
  const hostnames = await fetch(uri)
    .then((res) => res.json())
    .then((data) => data)
    .catch((_) => [])
    console.log(hostnames)
  return hostnames
}

export const fetchNodeConfig = async (flake: string, hostname: string): Promise<O.Option<Record<string, any>>> => {
  const uri = `${flake}/nixosConfigurations/${hostname}/default.json`
  const res = await fetch(uri)
    .then((res) => res.json())
    .then((data) => O.some(data))
    .catch((_) => O.none)
  return res
}

export const fetchNodeInitrdStatus = async (hostname: string) => {
  const initrdStatus = await fetch(`/nixosConfigurations/${hostname}/result/initrd.zst`, { method: 'HEAD' })
  return initrdStatus.ok && initrdStatus.status === 200
}

export const fetchNodeBzImageStatus = async (hostname: string) => {
  const bzImageStatus = await fetch(`/nixosConfigurations/${hostname}/result/bzImage`, { method: 'HEAD' })
  return bzImageStatus.ok && bzImageStatus.status === 200
}

export const fetchNodeKexecStatus = async (hostname: string) => {
  const kexecStatus = await fetch(`/nixosConfigurations/${hostname}/result/kexec-boot`, { method: 'HEAD' })
  return kexecStatus.ok && kexecStatus.status === 200
}

export const fetchNodeSSVKey = async (hostname: string): Promise<O.Option<string>> => {
  const pubKey = await fetch(`/nixosConfigurations/${hostname}/ssv_operator_key.pub`)
    .then((res) => res.text())
    .then((data) => O.some(data))
    .catch((_) => O.none)
  return pubKey
}

export type NodeInfo = {
  hostname: string
  hasInitrd: boolean
  hasBzImage: boolean
  hasKexec: boolean
  ssvKey: O.Option<string>
  config: O.Option<Record<string, any>>
}

export const NodeInfoContext = createContext<NodeInfo[]>([])

export function NodeInfoProvider(props: any) {
  const { newNodes }: any = useLoaderData();
  return <NodeInfoContext.Provider value={newNodes}>{props.children}</NodeInfoContext.Provider>
}

export function useNodeInfo() {
  const context = useContext(NodeInfoContext)
  if (context === undefined) {
    throw new Error('useNodeInfo must be used within a NodeInfoProvider')
  }
  return context
}
