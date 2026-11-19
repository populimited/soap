defmodule SoapTest do
  use ExUnit.Case
  import Mock
  alias Soap.{Response, Wsdl}

  @operation "SendMessage"
  @request_params %{inCommonParms: [{"userID", "WSPB"}]}

  test "#call was success" do
    {_, wsdl} = Fixtures.get_file_path("wsdl/SendService.wsdl") |> Wsdl.parse_from_file()
    response_xml = Fixtures.load_xml("send_service/SendMessageResponse.xml")
    http_result = {:ok, %{status_code: 200, body: response_xml, headers: [], request_url: nil}}

    with_mock Soap.HTTPClient.Req, post: fn _, _, _, _ -> http_result end do
      soap_response = %Response{status_code: 200, body: response_xml, headers: [], request_url: nil}
      assert(Soap.call(wsdl, @operation, @request_params) == {:ok, soap_response})
    end
  end

  test "#call can take request options" do
    {_, wsdl} = Fixtures.get_file_path("wsdl/SendService.wsdl") |> Wsdl.parse_from_file()
    response_xml = Fixtures.load_xml("send_service/SendMessageResponse.xml")
    http_result = {:ok, %{status_code: 200, body: response_xml, headers: [], request_url: nil}}
    req_opts = [receive_timeout: 1000]

    with_mock Soap.HTTPClient.Req, post: fn _, _, _, ^req_opts -> http_result end do
      soap_response = %Response{status_code: 200, body: response_xml, headers: [], request_url: nil}

      assert(Soap.call(wsdl, @operation, @request_params, [], receive_timeout: 1000) == {:ok, soap_response})
    end
  end

  test "#call was success, but fault" do
    {_, wsdl} = Fixtures.get_file_path("wsdl/SendService.wsdl") |> Wsdl.parse_from_file()
    fault_xml = Fixtures.load_xml("send_service/SendMessageFault.xml")
    http_result = {:ok, %{status_code: 500, body: fault_xml, request_url: nil, headers: []}}

    with_mock Soap.HTTPClient.Req, post: fn _, _, _, _ -> http_result end do
      soap_response = %Response{status_code: 500, body: fault_xml, headers: [], request_url: nil}
      assert(Soap.call(wsdl, @operation, @request_params) == {:ok, soap_response})
    end
  end

  test "#call returns error" do
    {_, wsdl} = Fixtures.get_file_path("wsdl/SendService.wsdl") |> Wsdl.parse_from_file()
    http_result = {:error, :something_wrong}

    with_mock Soap.HTTPClient.Req, post: fn _, _, _, _ -> http_result end do
      assert(Soap.call(wsdl, @operation, @request_params) == {:error, :something_wrong})
    end
  end

  test "to #call pass unknown soap operation" do
    {_, wsdl} = Fixtures.get_file_path("wsdl/SendService.wsdl") |> Wsdl.parse_from_file()
    operation = "IncorrectOperation"

    assert_raise OperationError, fn -> Soap.call(wsdl, operation, @request_params) end
  end

  test "#init_model with :url type can take request options" do
    wsdl_path = Fixtures.get_file_path("wsdl/SoapHeader.wsdl")
    {:ok, wsdl_body} = File.read(wsdl_path)
    {_, parsed_wsdl} = Wsdl.parse_from_file(wsdl_path)
    http_result = %{status_code: 200, body: wsdl_body, headers: [], request_url: nil}
    opts = [recv_timeout: 1000]
    opts_with_defaults = [follow_redirect: true, max_redirect: 5, recv_timeout: 1000]

    with_mock Soap.HTTPClient.Req, get!: fn _, _, ^opts_with_defaults -> http_result end do
      assert(Soap.init_model(wsdl_path, :url, opts) == {:ok, parsed_wsdl})
    end
  end
end
