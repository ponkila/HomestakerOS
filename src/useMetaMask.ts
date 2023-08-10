import { useEffect, useState } from 'react'
import detectEthereumProvider from '@metamask/detect-provider'

export type WalletState = {
  accounts: string[]
}

function useMetaMask() {
  const [hasProvider, setHasProvider] = useState<boolean | null>(null)
  const initialState = { accounts: [] }
  const [wallet, setWallet] = useState<WalletState>(initialState)

  const refreshAccounts = (accounts: string[]) => {
    if (accounts.length > 0) {
      setWallet({ accounts })
    } else {
      // if length 0, user is disconnected
      setWallet(initialState)
    }
  }

  useEffect(() => {
    const getProvider = async () => {
      const provider = await detectEthereumProvider({ silent: true })
      console.log(provider)
      setHasProvider(Boolean(provider)) // transform provider to true or false
      if (provider) {
        const accounts = await window.ethereum.request({ method: 'eth_accounts' })
        refreshAccounts(accounts)
        window.ethereum.on('accountsChanged', refreshAccounts)
      }
    }

    getProvider()
    return () => {
      window.ethereum?.removeListener('accountsChanged', refreshAccounts)
    }
  }, [])

  const handleConnect = async () => {
    const accounts = await window.ethereum.request({
      method: 'eth_requestAccounts',
    })
    setWallet({ accounts })
  }

  return [hasProvider, wallet, handleConnect] as const
}

export default useMetaMask
