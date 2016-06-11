# didx
Configures and starts a 'Docker In Docker' (dind) server container with its own local repository and and spins up an associated docker client container.  Once dind server and client have started, '''didx''' executes one or more scripts/programs within context of the dind client container.

Use didx to create a Docker test environment that's automatically destroyed after all tests successfully complete. 
