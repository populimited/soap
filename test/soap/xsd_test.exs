defmodule Soap.XsdTest do
  use ExUnit.Case
  doctest Soap.Xsd
  alias Soap.Xsd
  import Mock

  @xsd_path Fixtures.get_file_path("xsd/example.xsd")
  @raw_xsd Fixtures.load_xsd("example.xsd")
  @parsed_xsd %{
    complex_types: %{
      "purchaseordertype" => %{
        "BillTo" => %{type: "tns:USAddress"},
        "ShipTo" => %{maxOccurs: "2", type: "tns:USAddress"}
      },
      "usaddress" => %{
        "city" => %{type: "xsd:string"},
        "name" => %{type: "xsd:string"},
        "state" => %{type: "xsd:string"},
        "street" => %{type: "xsd:string"},
        "zip" => %{type: "xsd:integer"}
      }
    },
    simple_types: []
  }

  test "when file exists #parse returns corrent {:ok, data}" do
    assert Xsd.parse(@xsd_path) == {:ok, @parsed_xsd}
  end

  test "when file available on external resource" do
    with_mock Soap.HTTPClient.Req, get: fn _, _, _ -> {:ok, %{body: @raw_xsd, status_code: 200}} end do
      assert Xsd.parse("https://example.com") == {:ok, @parsed_xsd}
    end
  end

  test "when file not found on external resource" do
    with_mock Soap.HTTPClient.Req, get: fn _, _, _ -> {:ok, %{body: "", status_code: 404}} end do
      assert Xsd.parse("https://example.com") == {:error, :not_found}
    end
  end

  test "when response is error on external resource" do
    with_mock Soap.HTTPClient.Req, get: fn _, _, _ -> {:error, :forbidden} end do
      assert Xsd.parse("https://example.com") == {:error, :forbidden}
    end
  end
end
