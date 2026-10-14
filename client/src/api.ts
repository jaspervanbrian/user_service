import type {
  SessionResponse,
  UsersResponse,
  User,
  CreateUserInput,
  UpdateUserInput,
  ApiError,
} from './types';

const API_BASE = import.meta.env.VITE_API_URL || 'http://localhost:3000/api/v1';

export class ApiException extends Error {
  status: number;
  data: ApiError;

  constructor(status: number, data: ApiError) {
    const message =
      data.error ||
      (data.errors
        ? Object.entries(data.errors)
            .map(([field, msgs]) => `${field} ${msgs.join(', ')}`)
            .join('; ')
        : 'An unexpected API error occurred');
    super(message);
    this.status = status;
    this.data = data;
  }
}

async function request<T>(
  endpoint: string,
  options: RequestInit = {},
  token?: string | null
): Promise<T> {
  const headers = new Headers(options.headers || {});
  headers.set('Content-Type', 'application/json');
  headers.set('Accept', 'application/json');

  if (token) {
    headers.set('Authorization', `Bearer ${token}`);
  }

  const response = await fetch(`${API_BASE}${endpoint}`, {
    ...options,
    headers,
  });

  const contentType = response.headers.get('content-type');
  const isJson = contentType && contentType.includes('application/json');
  const body = isJson ? await response.json() : null;

  if (!response.ok) {
    throw new ApiException(response.status, body || { error: response.statusText });
  }

  return body as T;
}

export const api = {
  login: async (login: string, password: string): Promise<SessionResponse> => {
    return request<SessionResponse>('/sessions', {
      method: 'POST',
      body: JSON.stringify({ user: { login, password } }),
    });
  },

  getUsers: async (
    token: string,
    params: { cursor?: string | null; page?: number | null; limit?: number } = {}
  ): Promise<UsersResponse> => {
    const searchParams = new URLSearchParams();
    if (params.cursor) searchParams.set('cursor', params.cursor);
    if (params.page && params.page > 1) searchParams.set('page', params.page.toString());
    if (params.limit) searchParams.set('limit', params.limit.toString());

    const qs = searchParams.toString();
    return request<UsersResponse>(`/users${qs ? `?${qs}` : ''}`, {}, token);
  },

  getUser: async (token: string, id: number): Promise<{ user: User }> => {
    return request<{ user: User }>(`/users/${id}`, {}, token);
  },

  createUser: async (token: string, payload: CreateUserInput): Promise<{ user: User }> => {
    return request<{ user: User }>(
      '/users',
      {
        method: 'POST',
        body: JSON.stringify({ user: payload }),
      },
      token
    );
  },

  updateUser: async (
    token: string,
    id: number,
    payload: UpdateUserInput
  ): Promise<{ user: User }> => {
    return request<{ user: User }>(
      `/users/${id}`,
      {
        method: 'PATCH',
        body: JSON.stringify({ user: payload }),
      },
      token
    );
  },
};
