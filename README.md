                         ┌────────────────────┐
                         │  AWS Cognito (Auth)│
                         │  Email + Google    │
                         └─────────┬──────────┘
                                   │
                        JWT Tokens │
                                   ▼
 ┌──────────────────────────┐                 ┌────────────────────────────┐
 │    Frontend Repo (S3)    │  API Calls ---> │  Backend Repo (Lambda)     │
 │ React/Next.js app        │ <--- CORS <---- │ FastAPI via API Gateway    │
 │ Deployed to S3 + CF CDN  │                 │ Reads/Writes DynamoDB      │
 └───────────┬──────────────┘                 └────────────┬───────────────┘
             │                                              │
             │ Route 53 + ACM                               │ IAM + Logs
             ▼                                              ▼
       users.lms.app                              api.lms.app (Gateway)
