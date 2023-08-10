import React, { useState } from 'react'
import {
  Text,
  Button,
  Box,
  Code,
  Checkbox,
  CheckboxGroup,
  Flex,
  FormControl,
  FormLabel,
  FormErrorMessage,
  FormHelperText,
  Heading,
  Input,
  OrderedList,
  ListItem,
  Select,
  Slider,
  SliderTrack,
  SliderFilledTrack,
  SliderThumb,
  SliderMark,
  Spinner,
  Link,
} from '@chakra-ui/react'
import { ExternalLinkIcon } from '@chakra-ui/icons'
import { ethers } from 'ethers/dist/ethers.esm.js'
import useMetaMask from './useMetaMask'

const RegisterSSVForm = () => {
  const [hasProvider, wallet, handleConnect] = useMetaMask()
  const [nodeResponse, setNodeResponse] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState('')

  const registerOperator = async (e) => {
    e.preventDefault()
    setIsLoading(true)
    console.log(ethers)
    const coder = new ethers.utils.AbiCoder()
    const pk = e.target.publicKey.value
    const fee = Number(e.target.fee.value)
    console.log(pk, fee)
    const provider = new ethers.providers.Web3Provider(window.ethereum)
    const signer = await provider.getSigner();
    const abi = await (await fetch("/public/SSVNetwork.json")).json()
    //const contract = new ethers.Contract("0x8dB45282d7C4559fd093C26f677B3837a5598914", abi, provider) //views
    const contract = new ethers.Contract("0xAfdb141Dd99b5a101065f40e3D7636262dce65b3", abi, signer)
    contract.registerOperator(coder.encode(['string'], [pk]), fee, { gasLimit: 10000000 }).then((tx) => {
      console.log(tx)
      setIsLoading(false)
      setError('')
    }).catch((err) => {
      console.log(err)
      setError(err.message)
      setIsLoading(false)
    })
  }

  return (
    <>
      {error &&
        <Box bg='tomato' borderWidth="1px" w='100%' borderRadius="lg" color='white' my={4} p={4}>
          <Text>{error}</Text>
        </Box>
      }
      <Box borderWidth="1px" w='100%' borderRadius="lg" p={4}>
        <Heading as="h2" size="md" mb={4}>Register SSV operator</Heading>
        { !hasProvider ?
            <Link href="https://metamask.io/download" isExternal>
              <Button>
              Install MetaMask <ExternalLinkIcon mx="2px" />
              </Button>
            </Link>
          : (wallet.accounts.length === 0) &&
            <Button onClick={handleConnect}>
              Connect to MetaMask
            </Button>
        }
        { hasProvider && wallet.accounts.length > 0 &&
          (isLoading ? <Spinner /> :
            <form onSubmit={registerOperator}>
              <FormControl my={4}>
                <FormLabel>Owner</FormLabel>
                <Input disabled value={wallet.accounts[0] || ""} />
              </FormControl>
              <FormControl my={4} id="publicKey">
                <FormLabel>Public key</FormLabel>
                <Input placeholder="Public key" />
              </FormControl>
              <FormControl my={4} id="fee">
                <FormLabel>Fee</FormLabel>
                <Input placeholder="1.0" />
              </FormControl>
              <Button w="100%" type="submit">Register</Button>
            </form>
        )}
      </Box>
    </>
  )
}

export default RegisterSSVForm
