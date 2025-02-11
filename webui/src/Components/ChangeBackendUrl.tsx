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
        setBackendUrl(newUrl); // This will update the backend URL in memory and localStorage
    };

    return (
        <FormControl id="backend-url">
            <FormLabel>Backend URL</FormLabel>
            <Input
                type="url"
                placeholder="Enter backend URL"
                value={newUrl}
                onChange={handleChange}
            />
            <Button colorScheme='teal' type='submit' onClick={handleSave}>Save</Button>
        </FormControl>
    );
};

export default ChangeBackendUrl;
