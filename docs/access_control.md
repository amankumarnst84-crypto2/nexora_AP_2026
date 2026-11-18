# Authorization requirements

This is an implementation contract, not an audit of existing endpoints. Authentication uses the team's stated bcryptjs passwords and JWT cookies. Authorization must run on the server for every protected request.

| Action | Student | Staff |
|---|---|---|
| Read own profile and fixed bag | Yes | Only when needed for staff operations |
| Submit an order | Own bag only | Not a student impersonation flow |
| Read order details/history/timeline | Own orders only | Operational orders |
| Search all orders or assign a washing lot | No | Yes |
| Change order lifecycle or add delay reason | No | Yes |
| Create a complaint | Own order only | No student impersonation |
| Respond to a complaint | No | Yes |
| Confirm complaint resolution | Owning student only | No |

Derive user ID and role from a verified authenticated session; ignore a body-supplied user_id, role or bag owner. Check ownership even when the frontend hides links. A guessed order ID must not expose another student's clothes, timeline or complaints. Choose 403 or 404 for unauthorized object access consistently; never return the object's details with the error.

Return only safe user fields. Never serialize password_hash or tokens. Reject tampered/expired JWTs. Configure production cookies as HttpOnly and Secure with a SameSite policy appropriate to deployment; add CSRF protection for cross-site cookie-authenticated requests. A cookie alone is not an authorization check.

Student signup is still pending according to the team. When implemented, it must not allow the client to select STAFF or claim an already assigned bag. Define who verifies hostel/student identity before activating an account.
