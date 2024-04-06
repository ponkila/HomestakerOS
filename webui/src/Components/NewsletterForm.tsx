import { Button, Box, Flex, FormControl, FormLabel, Input, VStack } from '@chakra-ui/react'

const NewsletterForm = () => {
  return (
    <Box>
      <VStack>
        <FormLabel m={0}>Newsletter sign-up</FormLabel>
        <form
          action="https://buttondown.email/api/emails/embed-subscribe/ponkila"
          method="post"
          target="popupwindow"
          onSubmit={() => window.open('https://buttondown.email/ponkila', 'popupwindow')}
        >
          <Flex>
            <FormControl mr={4}>
              <Input size="xs" placeholder="home@staker.com" type="email" name="email" id="bd-email" />
            </FormControl>
            <Button size="xs" px={4} type="submit">
              Subscribe
            </Button>
          </Flex>
        </form>
      </VStack>
    </Box>
  )
}

export default NewsletterForm
