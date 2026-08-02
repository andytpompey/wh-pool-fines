# Accessing RooBin Commercial Operations

Commercial Operations is part of the normal RooBin web application; it is not
a separate provider portal.

1. Open `https://roobin.trovefinds.co.uk/app` and sign in with the production
   account that has platform-administrator permission.
2. In the signed-in header, select **Commercial**.
3. Alternatively, open `https://roobin.trovefinds.co.uk/admin/commercial`
   directly after signing in.
4. The page must show **Commercial Operations**. If it instead reports that
   platform-administrator access is required, stop: the signed-in account has
   not been granted `app_users.is_platform_admin` in the production database.

Do not attempt to grant this permission from a browser client or by changing a
team role. It is a separate platform-wide permission. Verify the exact signed-in
email before an existing production administrator applies the audited bootstrap
step.

The page contains catalogue/version administration, Stripe price binding,
discounts, controlled grants, support and incident operations, reconciliation,
commercial reporting and monthly provider usage/cost capture.
