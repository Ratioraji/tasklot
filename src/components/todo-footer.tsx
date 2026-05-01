"use client";

import { TodoFilters } from "@/components/todo-filters";
import type { TodoFilter } from "@/lib/types";

type Props = {
  activeCount: number;
  hasCompleted: boolean;
  filter: TodoFilter;
  onFilterChange: (filter: TodoFilter) => void;
  onClearCompleted: () => void;
};

export function TodoFooter({
  activeCount,
  hasCompleted,
  filter,
  onFilterChange,
  onClearCompleted,
}: Props) {
  return (
    <footer className="flex items-center justify-between gap-4 border-t border-gray-200 px-1 pt-4 text-xs text-gray-500">
      <span className="whitespace-nowrap">
        {activeCount} {activeCount === 1 ? "item" : "items"} left
      </span>

      <TodoFilters current={filter} onChange={onFilterChange} />

      <button
        type="button"
        onClick={onClearCompleted}
        disabled={!hasCompleted}
        className="whitespace-nowrap rounded px-2 py-1 text-xs text-gray-500 transition-colors hover:text-red-600 focus:outline-none focus:ring-2 focus:ring-red-500/20 disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:text-gray-500"
      >
        Clear completed
      </button>
    </footer>
  );
}
