import { useState } from 'react'
import { Text, Button, Box, FormControl, FormLabel, Heading, Input, Spinner, Link, Select } from '@chakra-ui/react'
import { ExternalLinkIcon } from '@chakra-ui/icons'
import { ethers } from 'ethers/dist/ethers.esm.js'
import useMetaMask from '../Hooks/useMetaMask'
import { useNodeInfo, NodeInfo } from '../Context/NodeInfoContext'
import * as O from 'fp-ts/Option'
import { getOrElse, isSome } from 'fp-ts/Option'

const RegisterSSVForm = () => {
  const [hasProvider, wallet, handleConnect] = useMetaMask()
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState('')
  const [node, setNode] = useState<NodeInfo | null>(null)
  const nodeInfo = useNodeInfo()

  const registerOperator = async (e: any) => {
    e.preventDefault()
    setIsLoading(true)
    console.log(ethers)
    const coder = new ethers.utils.AbiCoder()
    const pk = e.target.publicKey.value
    const fee = Number(e.target.fee.value)
    console.log(pk, fee)
    const provider = new ethers.providers.Web3Provider(window.ethereum)
    const signer = await provider.getSigner()
    const abi = await (await fetch('/SSVNetwork.json')).json()
    //const contract = new ethers.Contract("0x8dB45282d7C4559fd093C26f677B3837a5598914", abi, provider) //views
    const contract = new ethers.Contract('0xAfdb141Dd99b5a101065f40e3D7636262dce65b3', abi, signer)
    contract
      .registerOperator(coder.encode(['string'], [pk]), fee, { gasLimit: 10000000 })
      .then((tx: any) => {
        console.log(tx)
        setIsLoading(false)
        setError('')
      })
      .catch((err: Error) => {
        console.log(err)
        setError(err.message)
        setIsLoading(false)
      })
  }

  const onHostnameChange = (e: any) => {
    if (e.target.value) {
      setNode(e.target.value)
    } else {
      setNode(null)
    }
  }

  return (
    <>
      {error && (
        <Box bg="tomato" borderWidth="1px" w="100%" borderRadius="lg" color="white" my={4} p={4}>
          <Text>{error}</Text>
        </Box>
      )}
      <Box borderWidth="1px" w="100%" borderRadius="lg" p={4}>
        <Heading as="h2" size="md" mb={4}>
          Register SSV operator
        </Heading>
        {!hasProvider ? (
          <Link href="https://metamask.io/download" isExternal>
            <Button>
              Install MetaMask <ExternalLinkIcon mx="2px" />
            </Button>
          </Link>
        ) : (
          wallet.accounts.length === 0 && <Button onClick={handleConnect}>Connect to MetaMask</Button>
        )}
        {hasProvider &&
          wallet.accounts.length > 0 &&
          (isLoading ? (
            <Spinner />
          ) : (
            <form onSubmit={registerOperator}>
              <FormControl my={4}>
                <FormLabel>Owner</FormLabel>
                <Input disabled value={wallet.accounts[0] || ''} />
              </FormControl>
              <FormControl my={4}>
                <FormLabel>Hostname</FormLabel>
                <Select placeholder="Select hostname" onChange={onHostnameChange}>
                  {nodeInfo.map((node: NodeInfo) => (
                    <option key={node.hostname} value={node.hostname}>{node.hostname}</option>
                  ))}
                </Select>
              </FormControl>
              <FormControl my={4} id="publicKey">
                <FormLabel>Public key</FormLabel>
                <Input
                  disabled
                  value={getOrElse(() => "No public key available")(node?.ssvKey ?? O.none)}
                />
              </FormControl>
              <FormControl my={4} id="fee">
                <FormLabel>Fee</FormLabel>
                <Input placeholder="1.0" />
              </FormControl>
              <Button w="100%" type="submit" isDisabled={!isSome(node?.ssvKey ?? O.none)}>
                Register
              </Button>

            </form>
          ))}
      </Box>
    </>
  )
}

export default RegisterSSVForm
