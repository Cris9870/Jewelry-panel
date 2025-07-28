# Q'BellaJoyeria - Claude Code Guide

This guide provides essential information for Claude Code instances working on this codebase. The project is a jewelry store management system with features for inventory, orders, customers, and PDF generation.

## Project Overview

**Tech Stack:**
- Backend: Node.js + Express + MySQL
- Frontend: React + TypeScript + Vite
- Authentication: JWT
- PDF Generation: PDFKit
- Process Management: PM2
- Reverse Proxy: Nginx

## Common Commands

```bash
# Development (from root)
npm run install-all      # Install all dependencies
npm run dev             # Run both frontend and backend in dev mode
npm run dev-backend     # Run only backend
npm run dev-frontend    # Run only frontend

# Backend (from backend/)
npm start               # Start production server
npm run dev             # Start with nodemon

# Frontend (from frontend/)
npm run dev             # Start dev server
npm run build           # Build for production
npm run lint            # Run linter
```

## Critical Configuration

### Database Connection (backend/.env)
```env
DB_HOST=127.0.0.1  # MUST be 127.0.0.1, not localhost (IPv6 issue)
DB_USER=jewelry_user
DB_PASSWORD=your_password
DB_NAME=jewelry_panel
JWT_SECRET=your_jwt_secret_super_largo_y_seguro_minimo_32_caracteres
PORT=5000
NODE_ENV=production
```

### Frontend API Configuration
- Development: Uses `VITE_API_URL` from env or defaults to `http://localhost:5000/api`
- Production: Should use relative `/api` paths for Nginx reverse proxy

## Database Schema

Main tables:
- `users`: Admin authentication
- `categories`: Product categories
- `products`: Inventory with JSON attributes field
- `customers`: Customer records
- `orders`: Order headers with status and payment method
- `order_items`: Order line items

## API Routes

All routes prefixed with `/api`:
- `/auth/*` - Login/logout (no auth required for login)
- `/products/*` - CRUD + bulk import from Excel
- `/customers/*` - CRUD operations
- `/orders/*` - Create, list, update, PDF generation
- `/dashboard/*` - Analytics and metrics

All routes except `/auth/login` require JWT authentication via Bearer token.

## Key Features

1. **Stock Management**: Transaction-based updates to prevent race conditions
2. **Excel Import**: Bulk product upload via XLSX files
3. **PDF Generation**: Order receipts using PDFKit (replaced Puppeteer)
4. **Real-time Dashboard**: Sales metrics with Recharts
5. **Image Upload**: Product images via Multer

## Deployment Notes

### PM2 Configuration
- Must run from backend directory to avoid ESM conflicts
- `ecosystem.config.js` should be in backend folder

### Common Issues & Fixes

1. **MySQL Connection Error (::1:3306)**
   - Use `DB_HOST=127.0.0.1` instead of `localhost`

2. **Frontend Build Errors**
   - Set `verbatimModuleSyntax: false` in tsconfig.json
   - Ensure all imports use proper extensions

3. **PM2 ERR_REQUIRE_ESM**
   - Keep ecosystem.config.js in backend directory
   - Frontend has `"type": "module"` which conflicts

4. **Nginx Proxy**
   - Frontend should use relative paths (`/api`) in production
   - Nginx config maps `/api` to backend port 5000

## Project Structure

```
jewelry-panel/
├── backend/
│   ├── server.js           # Main Express server
│   ├── database/
│   │   └── schema.sql      # Database structure
│   ├── routes/             # API endpoints
│   ├── middleware/         # Auth & error handling
│   ├── utils/              # PDF generation
│   └── uploads/            # Product images
├── frontend/
│   ├── src/
│   │   ├── components/     # Reusable React components
│   │   ├── pages/          # Route pages
│   │   ├── services/       # API client
│   │   ├── contexts/       # Auth context
│   │   └── types/          # TypeScript interfaces
│   └── dist/               # Production build
└── deploy scripts          # Deployment automation
```

## Security Considerations

- Passwords hashed with bcrypt
- JWT tokens expire after 24 hours
- File uploads limited to images
- SQL injection prevented via parameterized queries
- CORS configured for production domain

## Testing & Validation

Before deployment:
1. Run `npm run build` in frontend
2. Test all CRUD operations
3. Verify PDF generation works
4. Check stock updates are atomic
5. Ensure Excel import handles errors gracefully

## Useful Deployment Scripts

- `deploy-ubuntu-final.sh`: Quick deployment with all fixes
- `deploy-ubuntu-interactive.sh`: Interactive deployment with prompts

Both scripts include all discovered fixes and optimal configurations.