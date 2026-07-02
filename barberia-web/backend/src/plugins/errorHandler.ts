import type { FastifyError, FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { Prisma } from '@prisma/client';

/** Traduce errores Prisma y genéricos a JSON legible para el panel. */
export function registerErrorHandler(app: FastifyInstance) {
  app.setErrorHandler((error: FastifyError, _request: FastifyRequest, reply: FastifyReply) => {
    if (reply.sent) return;

    const prismaMessage = mapPrismaError(error);
    if (prismaMessage) {
      const status = prismaMessage.status;
      return reply.status(status).send({ error: prismaMessage.message });
    }

    if (error.validation) {
      return reply.status(400).send({ error: 'Datos inválidos', details: error.validation });
    }

    const status = error.statusCode ?? 500;
    const message =
      status < 500 && error.message
        ? error.message
        : 'Error interno del servidor. Revisa los logs del backend.';

    if (status >= 500) {
      app.log.error(error);
    }

    return reply.status(status).send({ error: message });
  });
}

function mapPrismaError(error: unknown): { status: number; message: string } | null {
  if (!(error instanceof Prisma.PrismaClientKnownRequestError)) {
    if (error instanceof Prisma.PrismaClientInitializationError) {
      return {
        status: 503,
        message:
          'No se pudo conectar a PostgreSQL. Verifica que esté activo y DATABASE_URL en .env',
      };
    }
    return null;
  }

  switch (error.code) {
    case 'P1001':
      return {
        status: 503,
        message: 'Base de datos no disponible. ¿PostgreSQL está corriendo?',
      };
    case 'P2021':
    case 'P2022':
      return {
        status: 503,
        message: 'Esquema de base de datos desactualizado. Ejecuta: npm run db:push',
      };
    case 'P2002':
      return { status: 409, message: 'Ya existe un registro con esos datos' };
    case 'P2025':
      return { status: 404, message: 'Registro no encontrado' };
    default:
      return {
        status: 500,
        message: `Error de base de datos (${error.code}). Revisa los logs del backend.`,
      };
  }
}
