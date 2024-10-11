import { useContext, createContext, useState, useEffect } from 'react'
import * as O from 'fp-ts/Option'

export const fetchHostnames = async (flake: string): Promise<O.Option<string[]>> => {
  const uri = `${flake}/nixosConfigurations/hostnames.json`
  const hostnames = await fetch(uri)
    .then((res) => res.json())
    .then((data) => O.some(data))
    .catch((_) => O.none)
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

const fetchNodeInitrdStatus = async (hostname: string) => {
  const initrdStatus = await fetch(`/nixosConfigurations/${hostname}/result/initrd.zst`, { method: 'HEAD' })
  return initrdStatus.ok && initrdStatus.status === 200
}

const fetchNodeBzImageStatus = async (hostname: string) => {
  const bzImageStatus = await fetch(`/nixosConfigurations/${hostname}/result/bzImage`, { method: 'HEAD' })
  return bzImageStatus.ok && bzImageStatus.status === 200
}

const fetchNodeKexecStatus = async (hostname: string) => {
  const kexecStatus = await fetch(`/nixosConfigurations/${hostname}/result/kexec-boot`, { method: 'HEAD' })
  return kexecStatus.ok && kexecStatus.status === 200
}

export const fetchNodeSSVKey = async (hostname: string) => {
  const pubKey = await fetch(`/nixosConfigurations/${hostname}/ssv_operator_key.pub`)
    .then(async (res) => {
      if (!res.ok || res.status !== 200) {
        return null
      }
      return await res.text()
    })
    .catch((err) => {
      console.log(err)
      return null
    })

  return pubKey
}

export type NodeInfo = {
  hostname: string
  hasInitrd: boolean
  hasBzImage: boolean
  hasKexec: boolean
  ssvKey: string | null
  config: Record<string, any> | null
}

export const NodeInfoContext = createContext<NodeInfo[]>([])

export function NodeInfoProvider(props: any) {
  useState(props.flake)
  const [nodes, setNodes] = useState<NodeInfo[]>([])

  const refresh = async (flake: string) => {
    const hostnamesOption = await fetchHostnames(flake)
    const hostnames = O.getOrElse(() => new Array())(hostnamesOption)
    const newNodes = [
      ...nodes.filter((node) => hostnames.includes(node.hostname)),
      ...hostnames
        .filter((hostname) => !nodes.map((node) => node.hostname).includes(hostname))
        .map((hostname) => ({
          hostname,
          hasInitrd: false,
          hasBzImage: false,
          hasKexec: false,
          ssvKey: null,
          config: null,
        })),
    ]
    for (const node of newNodes) {
      if (!node.hasInitrd) {
        node.hasInitrd = await fetchNodeInitrdStatus(node.hostname)
      }
      if (!node.hasBzImage) {
        node.hasBzImage = await fetchNodeBzImageStatus(node.hostname)
      }
      if (!node.hasKexec) {
        node.hasKexec = await fetchNodeKexecStatus(node.hostname)
      }
      node.ssvKey = await fetchNodeSSVKey(node.hostname)
      const nodeConfigOption = await fetchNodeConfig(flake, node.hostname)
      node.config = O.getOrElseW(() => null)(nodeConfigOption)
    }
    setNodes(newNodes)
  }

  useEffect(() => {
    const flake: string = O.getOrElseW(() => "")(props.flake)
    refresh(flake)
  }, [props.flake])

  return <NodeInfoContext.Provider value={nodes}>{props.children}</NodeInfoContext.Provider>
}

export function useNodeInfo() {
  const context = useContext(NodeInfoContext)
  if (context === undefined) {
    throw new Error('useNodeInfo must be used within a NodeInfoProvider')
  }
  return context
}
