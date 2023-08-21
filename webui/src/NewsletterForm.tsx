import { Button, Box, Flex, FormControl, FormLabel, Input, VStack } from '@chakra-ui/react'

const NewsletterForm = () => {
  return (
    <Box>
      <VStack>
        <FormLabel m={0}>Newsletter sign-up</FormLabel>
        <Flex>
          <FormControl mr={4}>
            <Input size="xs" placeholder="home@staker.com" />
          </FormControl>
          <Button size="xs" px={4} type="submit">
            Subscribe
          </Button>
        </Flex>
      </VStack>
    </Box>
  )
}

export default NewsletterForm
