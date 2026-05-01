import { TodoApp } from "@/components/todo-app";

export function HomePage() {
  return (
    <main className="mx-auto flex w-full max-w-xl flex-col gap-8 px-4 py-12 sm:py-16">
      <div className="flex flex-col gap-1">
        <h1 className="text-2xl font-bold tracking-tight text-gray-900">
          Tasklot
        </h1>
        <p className="text-sm text-gray-500">
          Your tasks, organized and simple.
        </p>
      </div>
      <TodoApp />
    </main>
  );
}

export default HomePage;
