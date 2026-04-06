# ⚙️ Supabase Dashboard Configuration

To ensure Google Login and Authentication work seamlessly, please update the following settings in your **Supabase Dashboard**.

## 1. Authentication Status
- Go to **Authentication** → **Providers**.
- Ensure **Email** is enabled.
- Ensure **Google** is enabled (and your Client ID/Secret are correct).

## 2. URL Configuration (CRITICAL)
Go to **Authentication** → **URL Configuration**.

### Site URL
This is the default redirect for Web and general auth.
- **Set to:** `http://localhost:53018` (Matches your Flutter Web port)
- *Note: If you run flutter on a different port, update this accordingly.*

### Redirect URIs
Add the following to the **Additional Redirect URIs** list:
- `io.supabase.medicareai://callback` (For Mobile Deep Linking)
- `http://localhost:53018/**` (For Web Wildcard support)

## 3. Database Triggers
Ensure you have run the updated [fix_schema.sql](file:///d:/Degree_GLS/sem%205/Capstone/project/backend/fix_schema.sql). 
This trigger automatically creates users in the `public.users` table so you don't face "User not found" or RLS issues.

## 4. Email Templates (Optional)
If you enabled "Confirm Email" in Supabase, ensure the **Confirm Email** template contains:
`{{ .ConfirmationURL }}`
And that the "Redirect URL" for the email link is also set correctly in the URL configuration above.
