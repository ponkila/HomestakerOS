import { useState } from 'react'
import { Text, Button, Box, FormControl, FormLabel, Heading, Input, Spinner, Link, AlertIcon, Alert, Flex, Tooltip } from '@chakra-ui/react'
import { ExternalLinkIcon } from '@chakra-ui/icons'
import { ethers } from 'ethers/dist/ethers.esm.js'
import useMetaMask from '../Hooks/useMetaMask'
import { encodeAbiParameters, parseAbiParameters, parseEther } from "viem";
import { QuestionOutlineIcon } from '@chakra-ui/icons'

const enum ContractAddresses {
  Testnet = "0x38A4794cCEd47d3baf7370CcC43B560D3a1beEFA",
  Mainnet = "0xDD9BC35aE942eF0cFa76930954a156B3fF30a4E1",
}
const BLOCKS_PER_YEAR = 2613400n;
const USE_TEST_NET = true;

const RegisterSSVForm = () => {
  const [hasProvider, wallet, handleConnect] = useMetaMask()
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState('')
  const [transactionLink, setTransactionLink] = useState('')

  const registerOperator = async (e: any) => {
    e.preventDefault();
    setIsLoading(true);
    setTransactionLink('');
    setError('');
    try {
      const feeAsWei = parseEther(e.target.fee.value)
      const isZeroFee = feeAsWei === 0n;
      const feePerBlock = isZeroFee ? 0n : roundOperatorFee(feeAsWei / BLOCKS_PER_YEAR);

      const setPrivate = e.target.isPrivate.checked;
      if (isZeroFee && !Boolean(setPrivate)) {
        setError("Fee cannot be set to 0 while operator status is set to public. To set the fee to 0, switch the operator status to private.");
        setIsLoading(false);
        return;
      }

      const provider = new ethers.providers.Web3Provider(window.ethereum);
      const signer = provider.getSigner();

      const abi = await (await fetch('/SSVNetwork.json')).json();
      const address = USE_TEST_NET ? ContractAddresses.Testnet : ContractAddresses.Mainnet
      const contract = new ethers.Contract(address, abi, signer);
      const pk = e.target.publicKey.value;
      const publicKey = encodeAbiParameters(parseAbiParameters("string"), [pk]);
      const gasEstimate = await contract.estimateGas.registerOperator(publicKey, feePerBlock, setPrivate);

      contract
        .registerOperator(publicKey, feePerBlock, setPrivate, { gasLimit: gasEstimate })
        .then((tx: any) => {
          setIsLoading(false);
          setError('');
          const txLink = USE_TEST_NET ? `https://holesky.etherscan.io/tx/${tx.hash}` : `https://etherscan.io/tx/${tx.hash}`;
          setTransactionLink(txLink)
        })
    } catch (err: any) {
      setError(err.message);
      setIsLoading(false);
    }
  };

  const roundOperatorFee = (
    fee: bigint,
    precision = 10_000_000n,
  ): bigint => {
    return bigintRound(fee, precision);
  }

  const bigintRound = (value: bigint, precision: bigint): bigint => {
    const remainder = value % precision;
    return remainder >= precision / 2n
      ? value + (precision - remainder) // Round up
      : value - remainder; // Round down
  }

  return (
    <>
      {error && (
        <Box bg="tomato" borderWidth="1px" w="100%" borderRadius="lg" color="white" my={4} p={4}>
          <Text>{error}</Text>
        </Box>
      )}
      <Box borderWidth="1px" w="100%" borderRadius="lg" p={4}>
        <Flex>
          <Heading as="h2" size="md" mb={4}>
            Register SSV operator
          </Heading>
          <Link
            href="https://github.com/ponkila/HomestakerOS/blob/main/docs/homestakeros/3.2-ssv_node.md#register-as-an-ssv-operator"
            isExternal
            ml={2}
          >

            <Tooltip label="See documentation" aria-label="A tooltip">
              <QuestionOutlineIcon verticalAlign="middle" />
            </Tooltip>
          </Link>
        </Flex>
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
              <FormControl my={4} id="publicKey" isRequired>
                <FormLabel>Public key</FormLabel>
                <Input />
              </FormControl>
              <FormControl my={4} id="fee">
                <Flex as="span" align="center">
                  <FormLabel mb="0" whiteSpace="nowrap" verticalAlign="middle">Fee</FormLabel>
                  <Link
                    href="https://docs.google.com/spreadsheets/d/12cWougs1YjTd6gnsEvIZJMd0PXg_R3e7VkWyFXsmzbo/edit?pli=1&gid=549776430#gid=549776430"
                    isExternal
                  >
                    <Tooltip label="Link to recommended fees" aria-label="A tooltip">
                      <QuestionOutlineIcon verticalAlign="middle" />
                    </Tooltip>
                  </Link>
                </Flex>


                <Input mt={1} type="number" max="200" min="0" step="any" placeholder="1.0" />
              </FormControl>

              <FormControl my={4} id="isPrivate">
                <FormLabel>Private Operator</FormLabel>
                <input type="checkbox" name="isPrivate" />
              </FormControl>

              {transactionLink && (
                <Alert mb={5} status="success">
                  <AlertIcon />
                  Transaction submitted!
                  <Link ml={1} href={transactionLink} color="blue.500" isExternal>
                    View Transaction
                  </Link>
                </Alert>
              )}
              <Button w="100%" type="submit">
                Register
              </Button>

            </form>
          ))}
      </Box >
    </>
  )
}

export default RegisterSSVForm
