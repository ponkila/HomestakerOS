import { useContext, createContext, useState, useEffect } from 'react'

const fetchHostnames = async () => {
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

/*
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
*/

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

export const NodeInfoContext = createContext<string[]>([])

export function NodeInfoProvider({ children }: { children: any }) {
  const [hostnames, setHostnames] = useState<string[]>([])

  useEffect(() => {
    fetchHostnames().then((hostnames) => {
      setHostnames(hostnames)
    })

    const interval = setInterval(() => {
      fetchHostnames().then((hostnames) => {
        setHostnames(hostnames)
      })
    }, 10000)
    return () => clearInterval(interval)
  }, [])

  return <NodeInfoContext.Provider value={hostnames}>{children}</NodeInfoContext.Provider>
}

export function useNodeInfo() {
  const context = useContext(NodeInfoContext)
  if (context === undefined) {
    throw new Error('useNodeInfo must be used within a NodeInfoProvider')
  }
  return context
}
