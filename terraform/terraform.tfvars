# IAM Authentication Configuration
# Replace <Account ID> with your actual AWS account ID

# Configure which AWS accounts/roles can assume the API access roles
allowed_ingest_principals = [
  "arn:aws:iam::<Account ID:root"
]

allowed_read_principals = [
  "arn:aws:iam::<Account ID>:root"
]

allowed_full_access_principals = [
  "arn:aws:iam::<Account ID>:root"
]

# External IDs for additional security (change these to unique values)
external_id_ingest      = "ingest-external-id-12345"
external_id_read        = "read-external-id-67890"
external_id_full_access = "full-access-external-id-abcde"

