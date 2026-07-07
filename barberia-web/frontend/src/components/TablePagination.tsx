'use client';

import { SelectField } from '@/components/SelectField';

const DEFAULT_PAGE_SIZE_OPTIONS = [10, 25, 50, 100];

type TablePaginationProps = {
  page: number;
  pageSize: number;
  totalItems: number;
  onPageChange: (page: number) => void;
  onPageSizeChange: (pageSize: number) => void;
  pageSizeOptions?: number[];
};

export function TablePagination({
  page,
  pageSize,
  totalItems,
  onPageChange,
  onPageSizeChange,
  pageSizeOptions = DEFAULT_PAGE_SIZE_OPTIONS,
}: TablePaginationProps) {
  const totalPages = Math.max(1, Math.ceil(totalItems / pageSize));
  const safePage = Math.min(page, totalPages);
  const start = totalItems === 0 ? 0 : (safePage - 1) * pageSize + 1;
  const end = Math.min(safePage * pageSize, totalItems);

  const options = pageSizeOptions.map((size) => ({
    value: String(size),
    label: `${size} por página`,
  }));

  return (
    <div className="table-pagination" role="navigation" aria-label="Paginación de tabla">
      <p className="table-pagination-summary muted">
        {totalItems === 0
          ? 'Sin registros'
          : `Mostrando ${start}–${end} de ${totalItems}`}
      </p>

      <div className="table-pagination-controls">
        <label className="table-pagination-size">
          <span className="table-pagination-size-label">Filas</span>
          <SelectField
            compact
            value={String(pageSize)}
            onChange={(value) => onPageSizeChange(Number(value))}
            options={options}
            aria-label="Registros por página"
          />
        </label>

        <div className="table-pagination-nav">
          <button
            type="button"
            className="btn btn-secondary btn-compact"
            disabled={safePage <= 1}
            onClick={() => onPageChange(safePage - 1)}
            aria-label="Página anterior"
          >
            Anterior
          </button>
          <span className="table-pagination-page">
            Página {safePage} de {totalPages}
          </span>
          <button
            type="button"
            className="btn btn-secondary btn-compact"
            disabled={safePage >= totalPages}
            onClick={() => onPageChange(safePage + 1)}
            aria-label="Página siguiente"
          >
            Siguiente
          </button>
        </div>
      </div>
    </div>
  );
}
