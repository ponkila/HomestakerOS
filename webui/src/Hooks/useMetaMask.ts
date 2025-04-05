import { useEffect, useState } from 'react'
import detectEthereumProvider from '@metamask/detect-provider'

export type WalletState = {
  accounts: string[]
  chainId: Network | null
}
export enum Network {
  Ethereum = '0x1',
  Holesky = '0x4268',
}

function useMetaMask() {
  const [hasProvider, setHasProvider] = useState<boolean | null>(null)
  const initialState = { accounts: [], chainId: null }
  const [wallet, setWallet] = useState<WalletState>(initialState)

  const refreshAccounts = (accounts: string[]) => {
    if (accounts.length > 0) {
      setWallet((prevState) => ({ ...prevState, accounts }))
    } else {
      // if length 0, user is disconnected
      setWallet(initialState)
    }
  }

  const refreshNetwork = (chainId: Network) => {
    setWallet((prevState) => ({ ...prevState, chainId }))
  }

  useEffect(() => {
    const getProvider = async () => {
      const provider = await detectEthereumProvider({ silent: true })
      setHasProvider(Boolean(provider)) // transform provider to true or false
      if (provider) {
        const accounts = await window.ethereum.request({ method: 'eth_accounts' })
        const chainId = await window.ethereum.request({ method: 'eth_chainId' })
        refreshAccounts(accounts)
        refreshNetwork(chainId)

        window.ethereum.on('accountsChanged', refreshAccounts)
        window.ethereum.on('chainChanged', (newChainId: Network) => refreshNetwork(newChainId))
      }
    }

    getProvider()
    return () => {
      window.ethereum?.removeListener('accountsChanged', refreshAccounts)
      window.ethereum?.removeListener('chainChanged', refreshNetwork)
    }
  }, [])

  const handleConnect = async () => {
    const accounts = await window.ethereum.request({
      method: 'eth_requestAccounts',
    })
    setWallet((prevState) => ({ ...prevState, accounts }))
  }

  const switchNetwork = (networkId: string): Promise<any> => {
    return window.ethereum.request({
      method: 'wallet_switchEthereumChain',
      params: [{ chainId: networkId }],
    })
  }

  return [hasProvider, wallet, handleConnect, switchNetwork] as const
}

export default useMetaMask
