-- Create databases for each service
CREATE DATABASE smimekeys_client;
CREATE DATABASE policy;
CREATE DATABASE irisagent;
CREATE DATABASE mxengine;
CREATE DATABASE keycloak;
CREATE DATABASE dashboard;
CREATE DATABASE stalwart;

-- Grant privileges (using default postgres user)
GRANT ALL PRIVILEGES ON DATABASE smimekeys_client TO postgres;
GRANT ALL PRIVILEGES ON DATABASE policy TO postgres;
GRANT ALL PRIVILEGES ON DATABASE irisagent TO postgres;
GRANT ALL PRIVILEGES ON DATABASE mxengine TO postgres;
GRANT ALL PRIVILEGES ON DATABASE keycloak TO postgres;
GRANT ALL PRIVILEGES ON DATABASE dashboard TO postgres;
GRANT ALL PRIVILEGES ON DATABASE stalwart TO postgres;
