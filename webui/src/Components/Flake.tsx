import { Select } from '@chakra-ui/react'
import { Radio, Button, RadioGroup } from '@chakra-ui/react'
import { Input } from '@chakra-ui/react'
import { FormControl } from '@chakra-ui/react'
import * as O from 'fp-ts/Option'
import { useState } from 'react'

export const FlakeSection = (props: any) => {

  const [source, setSource] = useState('0')

  const radio = () => {
    return (
      <RadioGroup defaultValue="0" onChange={setSource}>
        <Radio value="0">Flake</Radio>
        <Radio value="1">URI</Radio>
      </RadioGroup>
    )
  }

  const input = source == "0" ? <Select name="uri">
    <option value="ponkila/homestaking-infra">ponkila/homestaking-infra</option>
  </Select> : <Input name="uri" required type='text' />

  const formatURI = (e: any) => {
    e.preventDefault();
    const form = new FormData(e.target);
    const uri = form.get("uri");
    props.setter(O.some(`https://raw.githubusercontent.com/${uri}/main`));
  }

  return (
    <>
      <form onSubmit={formatURI}>
        <fieldset>
          <p>Hello</p>
          <FormControl>
            {radio()}
            {input}
            <Button colorScheme='teal' type='submit'>Submit</Button>
          </FormControl>
        </fieldset>
      </form>
    </>
  )
}
