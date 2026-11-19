defmodule Soap.Request do
  @moduledoc """
  Documentation for Soap.Request.
  """
  alias Soap.Request.{Headers, Params}

  @doc """
  Executing with parsed wsdl and headers with body map.

  Calling the configured HTTP client (see `get_http_client/0`) with method,
  url, body, headers and options keys.
  """
  @spec call(wsdl :: map(), operation :: String.t(), params :: any(), headers :: any(), opts :: any()) :: any()
  def call(wsdl, operation, soap_headers_and_params, request_headers \\ [], opts \\ [])

  def call(wsdl, operation, {soap_headers, params}, request_headers, opts) do
    url = get_url(wsdl)
    operation = put_operation_prefix(operation)
    request_headers = Headers.build(wsdl, operation, request_headers)
    body = Params.build_body(wsdl, operation, params, soap_headers)

    get_http_client().post(url, body, request_headers, opts)
  end

  def call(wsdl, operation, params, request_headers, opts),
    do: call(wsdl, operation, {%{}, params}, request_headers, opts)

  @doc """
  The HTTP client used for requests and WSDL/XSD fetching.

  Configured with the `:http_client` key of the `:globals` application
  config; defaults to `Soap.HTTPClient.Req`. The module must expose
  `get!/3`, `get/3` and `post/4` returning normalized responses — see
  `Soap.HTTPClient.Req` for the contract.
  """
  @spec get_http_client() :: module()
  def get_http_client do
    Application.get_env(:soap, :globals)[:http_client] || Soap.HTTPClient.Req
  end

  @spec get_url(wsdl :: map()) :: String.t()
  defp get_url(wsdl) do
    wsdl.endpoint
  end

  @spec put_operation_prefix(operation :: String.t()) :: String.t()
  defp put_operation_prefix(operation) do
    case Application.get_env(:soap, :globals)[:operation_prefix] do
      nil ->
        operation

      prefix ->
        prefix <> ":" <> operation
    end
  end
end
