import 'dotenv/config';
import { mkdir } from 'node:fs/promises';
import { join } from 'node:path';
import Fastify from 'fastify';
import cors from '@fastify/cors';
import multipart from '@fastify/multipart';
import fastifyStatic from '@fastify/static';
import { registerAuthPlugin } from './plugins/auth.js';
import { registerAppAuthPlugin } from './plugins/appAuth.js';
import { authRoutes } from './routes/auth.js';
import { appAuthRoutes } from './routes/appAuth.js';
import { appSyncRoutes } from './routes/appSync.js';
import { registerErrorHandler } from './plugins/errorHandler.js';
import { tenantRoutes } from './routes/tenants.js';
import { tenantAppointmentsRoutes } from './routes/tenantAppointments.js';
import { tenantInvoicesRoutes } from './routes/tenantInvoices.js';
import { tenantServicesRoutes } from './routes/tenantServices.js';
import { userRoutes } from './routes/users.js';
import { appSettingsRoutes } from './routes/appSettings.js';

const port = Number(process.env.PORT ?? 3001);
const uploadDir = process.env.UPLOAD_DIR ?? './uploads';
const uploadPath = join(process.cwd(), uploadDir);

async function buildApp() {
  const app = Fastify({ logger: true });

  await app.register(cors, { origin: true, credentials: true });
  await app.register(multipart, { limits: { fileSize: 5 * 1024 * 1024 } });

  await mkdir(uploadPath, { recursive: true });
  await app.register(fastifyStatic, {
    root: uploadPath,
    prefix: '/uploads/',
    decorateReply: false,
  });

  await registerAuthPlugin(app);
  await registerAppAuthPlugin(app);
  registerErrorHandler(app);

  app.get('/health', async () => ({ status: 'ok' }));

  await app.register(authRoutes);
  await app.register(appAuthRoutes);
  await app.register(appSyncRoutes);
  await app.register(appSettingsRoutes);
  await app.register(tenantRoutes);
  await app.register(tenantAppointmentsRoutes);
  await app.register(tenantInvoicesRoutes);
  await app.register(tenantServicesRoutes);
  await app.register(userRoutes);

  return app;
}

const app = await buildApp();

try {
  await app.listen({ port, host: '0.0.0.0' });
} catch (err) {
  app.log.error(err);
  process.exit(1);
}
