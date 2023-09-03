import { useContext, createContext, useState, useEffect } from 'react'

const fetchHostnames = async (): Promise<string[]> => {
  const hostnames = await fetch('/nixosConfigurations/hostnames.json')
    .then(async (res) => {
      if (!res.ok || res.status !== 200) {
        return []
      }
      return await res.json()
    })
    .catch((err) => {
      console.log(err)
      return []
    })
  return hostnames
}

const fetchNodeConfig = async (hostname: string) => {
  const config = await fetch(`/nixosConfigurations/${hostname}/default.json`)
    .then(async (res) => {
      if (!res.ok || res.status !== 200) {
        return null
      }
      return await res.json()
    })
    .catch((err) => {
      console.log(err)
      return null
    })
  return config
}

const fetchNodeInitrdStatus = async (hostname: string) => {
  const initrdStatus = await fetch(`/nixosConfigurations/${hostname}/initrd.zst`, { method: 'HEAD' })
  return initrdStatus.ok && initrdStatus.status === 200
}

const fetchNodeBzImageStatus = async (hostname: string) => {
  const bzImageStatus = await fetch(`/nixosConfigurations/${hostname}/bzImage`, { method: 'HEAD' })
  return bzImageStatus.ok && bzImageStatus.status === 200
}

const fetchNodeKexecStatus = async (hostname: string) => {
  const kexecStatus = await fetch(`/nixosConfigurations/${hostname}/kexec-boot`, { method: 'HEAD' })
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

export function NodeInfoProvider({ children }: { children: any }) {
  const [nodes, setNodes] = useState<NodeInfo[]>([])

  const refresh = async () => {
    const hostnames = await fetchHostnames()
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
      node.config = await fetchNodeConfig(node.hostname)
    }
    setNodes(newNodes)
  }

  useEffect(() => {
    refresh()
    const interval = setInterval(() => {
      refresh()
    }, 10000)
    return () => clearInterval(interval)
  }, [])

  return <NodeInfoContext.Provider value={nodes}>{children}</NodeInfoContext.Provider>
}

export function useNodeInfo() {
  const context = useContext(NodeInfoContext)
  if (context === undefined) {
    throw new Error('useNodeInfo must be used within a NodeInfoProvider')
  }
  return context
}
