import { useState } from "react";
import { useBackend } from "../Context/BackendContext";
import { Button, FormControl, FormLabel, Input } from "@chakra-ui/react";

const ChangeBackendUrl = () => {
    const { backendUrl, setBackendUrl } = useBackend();
    const [newUrl, setNewUrl] = useState(backendUrl);

    const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        setNewUrl(e.target.value);
    };

    const handleSave = () => {
        setBackendUrl(newUrl); 
    };

    return (
        <FormControl id="backend-url" mb={5}>
            <FormLabel>Backend URL</FormLabel>
            <Input
                type="url"
                placeholder="Enter backend URL"
                value={newUrl}
                onChange={handleChange}
                mb={2}
            />
            <Button colorScheme='teal' type='submit' onClick={handleSave}>Save</Button>
        </FormControl>
    );
};

export default ChangeBackendUrl;

