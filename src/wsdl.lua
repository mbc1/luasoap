---------------------------'---------------------------------------------------
-- LuaSOAP support to WSDL semi-automatic generation.
-- See Copyright Notice in license.html
------------------------------------------------------------------------------

local soap = require"soap"
local strformat = require"string".format
local tconcat = require"table".concat

local M = {
	_COPYRIGHT = "Copyright (C) 2015 Kepler Project",
	_DESCRIPTION = "LuaSOAP provides a very simple API that convert Lua tables to and from XML documents",
	_VERSION = "LuaSOAP 4.0 WSDL generation helping functions",
}

-- internal data structure details
-- self.name -- service name
-- self.encoding -- string with XML encoding
-- self.targetNamespace -- target namespace
-- self.otherNamespaces -- optional table with other namespaces
-- self.url
-- self.wsdl -- string with complete WSDL document
-- self.types[..] -- table indexed by numbers (to guarantee the order of type definitions)
-- self.methods[methodName] -- table indexed by strings (each method name)
--	request -- table 
--		name -- string with message request name
--		[..] -- table with parameter definitions
--			name -- string with part name
--			element -- string with type element's name (optional)
--			type -- string with type (simple or complex) name (optional)
--	response -- idem
--	portTypeName -- string with portType name attribute
--	bindingName -- string with binding name attribute
--[=[
-- programador fornece a descrição abaixo:
methods = {
	GetQuote = {
		method = function (...) --[[...]] end,
		request = {
			name = "GetQuoteSoapIn",
			{ name = "parameters", element = "tns:GetQuote" },
		},
		response = {
			name = "GetQuoteSoapOut",
			{ name = "parameters", element = "tns:GetQuoteResponse" },
		},
		portTypeName = "StockQuoteSoap",
		bindingName = "StockQuoteSoap",
	},

}
=> soap.wsdl.generate_wsdl() produz a tabela abaixo e depois, serializa ela, produzindo o documento WSDL final:
{
	{
		tag = "wsdl:message",
		attr = { name = "GetQuoteSoapIn" },
		{
			tag = "wsdl:part",
			attr = { name = "parameters", element = "tns:GetQuote" }
		}
	},
	{
		tag = "wsdl:message",
		attr = { name = "GetQuoteSoapOut" },
		{
			tag = "wsdl:part",
			attr = { name = "parameters", element = "tns:GetQuoteResponse" }
		}
	},
	{
		tag = "wsdl:portType",
		attr = { name = "StockQuoteSoap" },
		{
			tag = "wsdl:operation",
			attr = { name = "GetQuote", parameterOrder = "??" },
			{
				tag = "wsdl:input",
				attr = { message = "tns:GetQuoteSoapIn" },
			},
			{
				tag = "wsdl:output",
				attr = { message = "tns:GetQuoteSoapOut" },
			},
		},
	},
...
}
--]=]

------------------------------------------------------------------------------
function M:gen_definitions ()
	return strformat([[
<wsdl:definitions
	xmlns:http="http://schemas.xmlsoap.org/wsdl/http/"
	xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
	xmlns:soap12="http://schemas.xmlsoap.org/wsdl/soap12/"
	xmlns:s="http://www.w3.org/2001/XMLSchema"
	xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/"
	xmlns:tns="%s"
	xmlns:mime="http://schemas.xmlsoap.org/wsdl/mime/"
	targetNamespace="%s"
	xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/ %s">]],
	self.targetNamespace, self.targetNamespace, soap.attrs (self.otherNamespaces))
end

------------------------------------------------------------------------------
function M:gen_types ()
	if self.types then
		self.types.tag = "wsdl:types"
		return soap.serialize (self.types)
	else
		return ''
	end
end

--=---------------------------------------------------------------------------
-- wsdl:message template
-- it should be cleaned each time it is used to eliminate old values.
--TODO Clean it 
local tmpl = {
	tag = "wsdl:message",
	attr = { name = "to be cleaned and refilled" },
	{
		tag = "wsdl:part",
		attr = { name = "parameters", type = nil, element = nil, },
	},
}

--=---------------------------------------------------------------------------
-- generate one <wsdl:message> element with two <wsdl:part> elements inside it.
-- @param elem Table with message description.
-- @param name String with type of message ("request" or "response").
-- @return String with a <wsdl:message>.

local function gen_message (elem, method_name)
	local message = {}	
	message.tag = "wsdl:message"
	message.attr = {}
	message.attr.name = assert (elem.name , method_name.."Message MUST have a name!")
		
	for i=1, #elem do 
	-- pode ter mais de um <wsdl:part> na mesma mensagem 
		message[i] = {}
		message[i].tag = "wsdl:part"
		message[i].name = assert (elem[i].name , method_name.."Message part MUST have a name!")
		if elem[i].element then
			message[i].attr = {}
			message[i].attr.element = elem[i].element
		elseif elem[i].type then
			message[i].attr = {}
			message[i].attr.type = elem[i].type
		else
			error ("Incomplete description: "..method_name.." in "..elem[i].name.." parameters MUST have an 'element' or a 'type' attribute")
		end
	-- pode ter os atributos type E element no mesmo <wsdl:part ...> ???
	-- acho que não, já que o  element se refere a um element em type e o type a um simpletype ou complex type
	end
	return soap.serialize (message)
end

------------------------------------------------------------------------------
-- generate two <wsdl:message> elements for each method.
-- @return String with all <wsdl:message>s.

function M:gen_messages ()
	local m = {}
	for method_name, desc in pairs (self.methods) do
		if desc.request then 
			m[#m+1] = gen_message (desc.request, method_name )
		end		
		if desc.response then 
			m[#m+1] = gen_message (desc.response, method_name )
		end		
		if desc.fault then 
			m[#m+1] = gen_message (desc.fault, method_name )
		end		
		-- Sim, você pode não ter nenhuma mensagem
	end
	return tconcat (m)
end

------------------------------------------------------------------------------
-- wsdl:portType template
-- it should be cleaned each time it is used to eliminate old values.
--TODO Clean it!!!

local tmpl_portType = {
	tag = "wsdl:portType",
	attr = { name = "StockQuoteSoap" },
	{
		tag = "wsdl:operation",
		attr = { name = "GetQuote", parameterOrder = "??" },
		{
			tag = "wsdl:input",
			attr = { message = "GetQuoteSoapIn" },
		},
		{
			tag = "wsdl:output",
			attr = { message = "GetQuoteSoapOut" },
		},
	},
}
------------------------------------------------------------------------------
-- generate portType

local function gen_portType (desc, method_name)
	local portType = {}
	portType.tag = "wsdl:portType"
	portType.attr = {}
	portType.attr.name = assert (desc.portTypeName , method_name.."You MUST have a portTypeName!")

	portType[1] = {}
	portType[1].tag = "wsdl:operation"	
	portType[1].attr.name = method_name
	--TODO parameterOrder??

	local tab = {}
	if desc.request then
		tab.tag = "wsdl:input"
		tab.attr = {}
		tab.attr.message = (desc.namespace or "tns:")..desc.request.name 
		portType[1][ #portType[1] + 1] = tab 
	end
	if desc.response then
		tab.tag = "wsdl:output"
		tab.attr = {}
		tab.attr.message = (desc.namespace or "tns:")..desc.response.name 
		portType[1][ #portType[1] + 1] = tab 
	end
	if desc.fault then
		tab.tag = "wsdl:fault"
		tab.attr.message = (desc.namespace or "tns:")..desc.fault.name 
		portType[1][ #portType[1] + 1] = tab 
	end
	--TODO Como alterar a ordem entre input e output para uma operação output->input ???

	return soap.serialize (portType)
end

------------------------------------------------------------------------------
-- generate portTypes

function M:gen_portTypes ()
	local p = {}
	for method_name, desc in pairs (self.methods) do
		p[#p+1] = gen_portType (desc, method_name)
	end
	return tconcat (p)
end

------------------------------------------------------------------------------
--Generate binding

local function gen_binding (desc, method_name)
	local binding = {} -- TODO Esse nome ta meio ingrato ???
	binding.tag = "wsdl:binding"
	binding.attr = {}
	binding.attr.name = assert (desc.bindingName , method_name.."You MUST have a bindingName!")
	binding.attr.type = ( desc.namespace or "tns:")..desc.portTypeName

	binding[1] = {}
	binding[1].tag = "wsdl:operation"	
	binding[1].attr = {}
	binding[1].attr.name = method_name

	local tab = {}
	if desc.request then
		tab.tag = "wsdl:input"
		binding[1][ #binding[1] + 1] = tab 
	end
	if desc.response then
		tab.tag = "wsdl:output"
		binding[1][ #binding[1] + 1] = tab 
	end
	if desc.fault then
		tab.tag = "wsdl:fault"
		binding[1][ #binding[1] + 1] = tab 
	end
	--TODO Como acrescentar e calcular os SOAP binding ???
	
	return soap.serialize (binding)
end

------------------------------------------------------------------------------
--Generate bindings

function M:gen_bindings ()
	local b = {}
	for method_name, desc in pairs (self.methods) do
		b[#b+1] = gen_binding (desc, method_name)
	end
	return tconcat (b)
	

end

------------------------------------------------------------------------------
--Generate port

local function gen_port (desc, method_name)
	local port = {}
	port.tag = "wsdl:port"
	port.attr = {}
	port.attr.name = bindingName
	port.attr.binding = (desc.namespace or "tns:")..bindingName
	--Como calcular o que acrecentar dentro do port ???
	return port
end

------------------------------------------------------------------------------
--Generate service

function M:gen_service ()
	local service = {} 
	service.tag = "wsdl:service"
	service.attr = {}
	service.attr.name = self.name
	for method_name, desc in pairs (self.methods) do
		service[#service+1] = gen_port (desc, method_name)
	end
	return soap.serialize (service)
end

------------------------------------------------------------------------------
function M:generate_wsdl ()
	if self.wsdl then
		return self.wsdl
	end
	local doc = {}
	doc[1] = self:gen_definitions ()
	doc[2] = self:gen_types ()
	doc[3] = self:gen_messages ()
	doc[4] = self:gen_portTypes ()
	doc[5] = self:gen_bindings ()
	doc[6] = self:gen_service ()
	doc[7] = "</wsdl:definitions>"
	return tconcat (doc)
end

------------------------------------------------------------------------------
return M