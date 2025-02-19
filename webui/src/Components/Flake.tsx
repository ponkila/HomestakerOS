import { Select, Radio, Button, RadioGroup, Input, FormControl, HStack } from '@chakra-ui/react'
import { useState } from 'react'
import { useBackend } from '../Context/BackendContext'
export const FlakeSection = () => {
  const [source, setSource] = useState('0')
  const { backendUrl } = useBackend();

  const radio = () => (
    <RadioGroup defaultValue="0" onChange={setSource} pr={2}>
      <HStack spacing={4}>  {/* Add spacing between radio buttons */}
        <Radio value="0">Flake</Radio>
        <Radio value="1">URI</Radio>
        <Radio value="2">Demo</Radio>
      </HStack>
    </RadioGroup>
  );

  const input = source === "0" ? (
    <Select name="uri" mr={2}>
      <option value="ponkila/homestaking-infra">ponkila/homestaking-infra</option>
    </Select>
  ) : source === "1" ? (
    <Input name="uri" required type='text' />
  ) : null

  const formatURI = (e: any) => {
    e.preventDefault();
    const form = new FormData(e.target);
    const uri = form.get("uri");

    window.location.replace(`/${uri}#backendUrl=${encodeURIComponent(backendUrl)}`);  }

  return (
    <form onSubmit={formatURI}>
      <fieldset>
        <FormControl>
          {radio()}
          {input}
          <Button colorScheme='teal' type='submit' mt={2}>Submit</Button>
        </FormControl>
      </fieldset>
    </form>
  )
}