# Nuxt 3 Premium SaaS Template

A modern, highly optimized, and responsive SaaS Administration Dashboard template built with Nuxt 3, Vue 3, Element Plus, and Prisma ORM. 

Designed for high-performance enterprise applications, this template features out-of-the-box Multi-tenancy, Role-Based Access Control (RBAC), and a seamless responsive UI that adapts intelligently from Desktop to Mobile.

## 🚀 Features

### Frontend (UI/UX)
- **Framework**: Powered by [Nuxt 3](https://nuxt.com/) and Vue 3 (Composition API, `<script setup>`).
- **Premium Design System**: Customized [Element Plus](https://element-plus.org/) with SCSS Modules (`.module.scss`) for scoped, conflict-free styling. No Tailwind dependency.
- **Responsive & Mobile-First**: 
  - **Desktop/Tablet**: Comprehensive Data Tables, Persistent Sidebar, and dense information layout.
  - **Mobile**: Transforms into a mobile-native experience using Bottom Navigation, Infinity Scroll, and Touch-friendly Card Layouts.
- **Dark/Light Mode**: First-class theme switcher out-of-the-box.
- **Internationalization (i18n)**: Multi-language support (`vi` / `en`) via `@nuxtjs/i18n`.

### Backend (API & Database)
- **Database / ORM**: [Prisma](https://www.prisma.io/). Type-safe database queries.
- **Multi-tenancy Architecture**: Strict data isolation by Tenant ID via middleware and Prisma queries.
- **Authentication**: JWT-based authentication system.
- **RBAC (Role-Based Access Control)**: Granular permissions, Admin/User roles.
- **Soft Deletes**: Safe deletion mechanism for critical tables (Users, Roles, Tenants).
- **System Logging**: Automatic tracking of mutating actions (Create/Update/Delete).

## 📂 Project Structure

```
├── assets/
│   ├── scss/          # Global styles, CSS Variables, and Design Tokens
├── components/        # Reusable Vue components (UI blocks, Mobile Nav, Sidebar)
├── i18n/              # Locales (en.json, vi.json)
├── layouts/           # Application layouts (Default, Auth, Mobile optimized)
├── pages/             # Application views (Dashboard, Users, Roles, etc.)
├── prisma/            # Prisma schema, migrations, and seed files
├── server/
│   ├── api/           # Nuxt Nitro API endpoints (CRUD operations)
│   ├── middleware/    # Auth and Tenant verification
│   └── utils/         # Helper functions (System logs, Prisma client)
├── stores/            # Pinia global state management (Auth, App layout state)
└── nuxt.config.ts     # Nuxt configuration
```

## 🛠️ Setup & Installation

Make sure to install dependencies:

```bash
# npm
npm install

# pnpm
pnpm install

# yarn
yarn install
```

### Environment Variables

Create a `.env` file in the root directory and configure your database and JWT secret:

```env
DATABASE_URL="postgresql://user:password@localhost:5432/mydb?schema=public"
JWT_SECRET="your_super_secret_key_here"
```

### Database Setup

Run Prisma migrations to initialize your database schema:

```bash
npx prisma migrate dev
npx prisma generate
```

*(Optional) Seed the database with default Admin user and roles:*
```bash
npx prisma db seed
```

## 💻 Development Server

Start the development server on `http://localhost:3000`:

```bash
npm run dev
```

## 📦 Production

Build the application for production:

```bash
npm run build
```

Locally preview production build:

```bash
npm run preview
```

## 🎨 Styling Guidelines
- **Always** use CSS Modules (`[name].module.scss`) for component and page styling.
- **Never** use `<style scoped>` directly in `.vue` files.
- Use camelCase for CSS classes (e.g., `.pageContainer`, `.fwBold`).
- Apply classes via dynamic binding: `:class="styles.pageContainer"`.

---
*Built with ❤️ using Nuxt & Element Plus.*
