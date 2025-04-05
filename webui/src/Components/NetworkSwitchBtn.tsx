import React, { useState } from 'react'
import { Tag, TagLabel, Select, Box, Flex, Text } from '@chakra-ui/react' // Importing Chakra UI components
import { WalletState, Network } from '../Hooks/useMetaMask' // Assuming you have WalletState typed

const NetworkSwitchBtn: React.FC<{
  wallet: WalletState
  switchNetwork: (networkId: string) => Promise<any>
  handleConnect: () => void
}> = ({ wallet, switchNetwork, handleConnect }) => {
  const [error, setError] = useState('')
  // Handle network change when the user selects a new network
  const handleSelectChange = async (event: React.ChangeEvent<HTMLSelectElement>) => {
    const selectedNetwork = event.target.value as keyof typeof Network
    try {
      setError('')
      await switchNetwork(selectedNetwork)
    } catch (error) {
      setError('Unable to switch the network. Try to do it manually!')
    }
  }

  return (
    <Box>
      {wallet.accounts.length > 0 ? (
        <Box>
          <Flex alignItems="center" gap="4">
            <Select value={wallet.chainId ?? 'Select network'} onChange={handleSelectChange} size="lg" width="auto">
              <option value={Network.Ethereum}>Ethereum</option>
              <option value={Network.Holesky}>Holesky</option>
            </Select>

            <Tag size="lg" colorScheme="green" borderRadius="full" variant="solid" cursor="pointer">
              <TagLabel>
                {wallet.accounts[0].slice(0, 6)}...{wallet.accounts[0].slice(-4)}
              </TagLabel>
            </Tag>
          </Flex>
          {error !== '' ? (
            <Text fontSize="md" color="red" textAlign="center">
              {error}
            </Text>
          ) : null}
        </Box>
      ) : (
        <Tag size="lg" colorScheme="blue" borderRadius="full" variant="solid" cursor="pointer" onClick={handleConnect}>
          <TagLabel>Connect MetaMask</TagLabel>
        </Tag>
      )}
    </Box>
  )
}

export default NetworkSwitchBtn
