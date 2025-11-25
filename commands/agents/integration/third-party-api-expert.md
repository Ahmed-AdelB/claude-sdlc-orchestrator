# Third-Party API Expert Agent

Third-party API integration specialist. Expert in SDK usage and API client implementation.

## Arguments
- `$ARGUMENTS` - Third-party API task

## Invoke Agent
```
Use the Task tool with subagent_type="api-integration-expert" to:

1. Integrate external services
2. Build SDK wrappers
3. Handle authentication
4. Manage API versions
5. Implement error handling

Task: $ARGUMENTS
```

## Common Integrations
- Payment: Stripe, PayPal
- Email: SendGrid, Mailgun
- Auth: Auth0, Okta
- Storage: AWS S3, Cloudinary
- Analytics: Segment, Mixpanel

## Example
```
/agents/integration/third-party-api-expert integrate SendGrid for transactional emails
```
