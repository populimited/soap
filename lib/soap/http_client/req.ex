defmodule Soap.HTTPClient.Req do
  @moduledoc """
  The default HTTP client, built on `Req`.

  Success responses are normalized to a plain map with the `:status_code`,
  `:headers`, `:request_url` and `:body` keys, and failures to
  `{:error, reason}` — the shapes `Soap`, `Soap.Wsdl` and `Soap.Xsd` consume.
  A custom `:http_client` (see `Soap.Request.get_http_client/0`) must return
  the same shapes.

  Some HTTPoison-style options are translated to their Req equivalents:

    * `:follow_redirect` (HTTPoison) → `:redirect` (Req)
    * `:max_redirect` (HTTPoison) → `:max_redirects` (Req)
    * `:recv_timeout` and `:timeout` (HTTPoison) → `:receive_timeout` (Req)
    * `:connect_timeout` (HTTPoison) → `:connect_options[:timeout]` (Req)

  Any other option is passed through to `Req.request/1`, so Req-native
  options (`:auth`, `:plug`, ...) can be used directly. Redirect following
  is enabled, retries are always disabled, and the response body is kept raw
  (no decompression or decoding), as the SOAP pipeline parses the body
  itself.
  """

  @defaults [raw: true, retry: false, redirect: true]

  @spec get!(String.t(), list(), list()) :: map()
  def get!(url, headers \\ [], opts \\ []) do
    case get(url, headers, opts) do
      {:ok, response} -> response
      {:error, reason} -> raise "SOAP request failed: #{inspect(reason)}"
    end
  end

  @spec get(String.t(), list(), list()) :: {:ok, map()} | {:error, term()}
  def get(url, headers \\ [], opts \\ []), do: request(:get, url, nil, headers, opts)

  @spec post(String.t(), binary(), list(), list()) :: {:ok, map()} | {:error, term()}
  def post(url, body, headers \\ [], opts \\ []), do: request(:post, url, body, headers, opts)

  defp request(method, url, body, headers, opts) do
    request = [
      method: method,
      url: url,
      headers: headers,
      body: body
    ]

    case Req.request(Keyword.merge(request, translate_opts(opts))) do
      {:ok, %Req.Response{} = response} ->
        {:ok,
         %{
           status_code: response.status,
           headers: response_headers(response),
           request_url: url,
           body: response.body
         }}

      {:error, exception} ->
        {:error, Exception.message(exception)}
    end
  end

  # Req accumulates headers in a map of lists, while HTTPoison reported
  # them as a list of tuples; normalize for `Soap.Response`.
  defp response_headers(%Req.Response{headers: headers}) do
    Enum.map(headers, fn {name, values} -> {name, Enum.join(values, ", ")} end)
  end

  defp translate_opts(opts) do
    {translated, opts} = translate_redirect(opts)
    {translated, opts} = pop_timeout(opts, :recv_timeout, translated)
    {translated, opts} = pop_timeout(opts, :timeout, translated)
    {translated, opts} = pop_connect_timeout(opts, translated)

    @defaults ++ opts ++ translated
  end

  defp translate_redirect(opts) do
    {translated, opts} =
      case Keyword.pop(opts, :follow_redirect) do
        {nil, opts} -> {[], opts}
        {true, opts} -> {[], opts}
        {false, opts} -> {[redirect: false], opts}
      end

    case Keyword.pop(opts, :max_redirect) do
      {nil, opts} -> {translated, opts}
      {max, opts} -> {Keyword.put(translated, :max_redirects, max), opts}
    end
  end

  defp pop_timeout(opts, key, translated) do
    case Keyword.pop(opts, key) do
      {nil, opts} -> {translated, opts}
      {value, opts} -> {Keyword.put(translated, :receive_timeout, value), opts}
    end
  end

  defp pop_connect_timeout(opts, translated) do
    case Keyword.pop(opts, :connect_timeout) do
      {nil, opts} ->
        {translated, opts}

      {value, opts} ->
        connect_options = Keyword.get(translated, :connect_options, [])
        {Keyword.put(translated, :connect_options, connect_options ++ [timeout: value]), opts}
    end
  end
end
