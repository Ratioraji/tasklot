"use client";

import type { TodoFilter } from "@/lib/types";

const FILTERS: { value: TodoFilter; label: string }[] = [
  { value: "all", label: "All" },
  { value: "active", label: "Active" },
  { value: "completed", label: "Completed" },
];

type Props = {
  current: TodoFilter;
  onChange: (filter: TodoFilter) => void;
};

export function TodoFilters({ current, onChange }: Props) {
  return (
    <div className="flex gap-1" role="group" aria-label="Filter todos">
      {FILTERS.map(({ value, label }) => {
        const isActive = current === value;
        return (
          <button
            key={value}
            type="button"
            aria-pressed={isActive}
            onClick={() => onChange(value)}
            className={`rounded px-2.5 py-1 text-xs font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500/20 ${
              isActive
                ? "bg-blue-600 text-white"
                : "text-gray-600 hover:bg-gray-100"
            }`}
          >
            {label}
          </button>
        );
      })}
    </div>
  );
}
