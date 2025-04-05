import React from 'react'
import { Tag, TagLabel, Box, Flex, Menu, MenuButton, MenuItem, MenuList, Button, useToast } from '@chakra-ui/react' // Importing Chakra UI components
import { WalletState, Network } from '../Hooks/useMetaMask' // Assuming you have WalletState typed

const NetworkSwitchBtn: React.FC<{
  wallet: WalletState
  switchNetwork: (networkId: Network) => Promise<any>
  handleConnect: () => void
}> = ({ wallet, switchNetwork, handleConnect }) => {
  const toast = useToast()

  // Handle network change when the user selects a new network
  const handleSelectChange = async (selectedNetwork: Network) => {
    try {
      if (selectedNetwork === Network.None) {
      } else {
        await switchNetwork(selectedNetwork)
      }
    } catch (error: any) {
      toast({
        title: 'Error',
        description: 'Network switch failed. Try to do it manually from MetaMask!',
        status: 'error',
        duration: 3000,
        isClosable: true,
      })
    }
  }

  const getNetworkName = (chainId: Network) => {
    switch (chainId) {
      case Network.Ethereum:
        return 'Ethereum'
      case Network.Holesky:
        return 'Holesky'
      default:
        return 'Invalid Network'
    }
  }

  return (
    <Box>
      {wallet.accounts.length > 0 ? (
        <Box>
          <Flex alignItems="center" gap="4">
            <Menu>
              {wallet.chainId === Network.None ? (
                <MenuButton as={Button} size="md" width="auto" bg="red.400">
                  Invalid Network
                </MenuButton>
              ) : (
                <MenuButton as={Button} size="md" width="auto">
                  {getNetworkName(wallet.chainId)}
                </MenuButton>
              )}
              <MenuList>
                {/* Ethereum */}
                <MenuItem onClick={() => handleSelectChange(Network.Ethereum)}>Ethereum</MenuItem>
                {/* Holesky */}
                <MenuItem onClick={() => handleSelectChange(Network.Holesky)}>Holesky</MenuItem>
              </MenuList>
            </Menu>

            <Tag size="lg" colorScheme="green" borderRadius="full" variant="solid" cursor="pointer">
              <TagLabel>
                {wallet.accounts[0].slice(0, 6)}...{wallet.accounts[0].slice(-4)}
              </TagLabel>
            </Tag>
          </Flex>
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
