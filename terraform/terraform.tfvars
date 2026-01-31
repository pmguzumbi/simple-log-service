# IAM Authentication Configuration
# Replace 033667696152 with your actual AWS account ID

# Configure which AWS accounts/roles can assume the API access roles
allowed_ingest_principals = [
  "arn:aws:iam::033667696152:root"
]

allowed_read_principals = [
  "arn:aws:iam::033667696152:root"
]

allowed_full_access_principals = [
  "arn:aws:iam::033667696152:root"
]

# External IDs for additional security (change these to unique values)
external_id_ingest      = "ingest-external-id-12345"
external_id_read        = "read-external-id-67890"
external_id_full_access = "full-access-external-id-abcde"

