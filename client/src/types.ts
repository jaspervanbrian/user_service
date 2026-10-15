export type Role = 'member' | 'admin';

export interface User {
  id: number;
  username: string;
  first_name: string;
  last_name: string;
  role: Role;
  email?: string;
  date_of_birth?: string | null;
  created_at?: string;
  updated_at?: string;
}

export interface PaginationMeta {
  next_cursor: string | null;
  has_next_page: boolean;
  limit: number;
  page?: number;
}

export interface UsersResponse {
  users: User[];
  pagination: PaginationMeta;
}

export interface SessionResponse {
  token: string;
  token_type: string;
  expires_in: number;
  user: User;
}

export interface ApiError {
  error?: string;
  errors?: Record<string, string[]>;
}

export interface CreateUserInput {
  first_name: string;
  last_name: string;
  username: string;
  email: string;
  password: string;
  password_confirmation?: string;
  date_of_birth?: string;
  role?: Role;
}

export interface UpdateUserInput {
  first_name?: string;
  last_name?: string;
  username?: string;
  email?: string;
  password?: string;
  date_of_birth?: string | null;
  role?: Role;
}
