-module(stomp_frame).

-include_lib("eunit/include/eunit.hrl").

-compile(export_all).

parse(FrameText) ->
	Parts = split_frame(FrameText),
	Envelope = lists:nth(1, Parts),
	Body = lists:nth(2, Parts),
	
	Tokens = string:tokens(Envelope, "\n"),
	Command = lists:nth(1, Tokens),
	Headers = parse_headers(lists:delete(Command, Tokens)),
	{frame, Command, Headers, Body}.

split_frame(FrameText) ->
	SplitLocation = string:str(FrameText, "\n\n"),
	Envelope = string:substr(FrameText, 1, SplitLocation - 1),
	Body = string:substr(FrameText, SplitLocation + 2),
	[Envelope, Body].

parse_headers([]) -> [];
parse_headers([HeaderText | Others]) ->
	Tokens = string:tokens(HeaderText, ":"),
	Key = lists:nth(1, Tokens),
	Value = lists:nth(2, Tokens),
	[{Key, Value} | parse_headers(Others)].

get_command({frame, Command, _Headers, _Body}) -> Command.
get_headers({frame, _Command, Headers, _Body}) -> Headers.
get_body({frame, _Command, _Headers, Body}) -> Body.

get_header(Frame, Key) ->
	Headers = get_headers(Frame),
	Pairs = lists:filter(fun({K, _V}) -> K == Key end, Headers),
	case Pairs of
		[] -> {error, "header doesn't exist: " ++ Key}; 
		[{_Key, Value} | _] -> Value;
		_Other -> {error, "frame structure error"}
	end.

%% Tests

simple_frame_test_() ->
	FrameText = "COMMAND\nname:value\nfoo:bar\n\nmessage body\n",
	Frame = parse(FrameText),
	Command = get_command(Frame),
	Headers = get_headers(Frame),
	Body = get_body(Frame),
	[
	?_assertMatch("COMMAND", Command),
	?_assertMatch([{"name", "value"}, {"foo", "bar"}], Headers),
	?_assertMatch("message body\n", Body),
	?_assertMatch(1, 1)
	].

get_header_test_() ->
	FrameText = "COMMAND\nname:value\nfoo:bar\n\nmessage body\n",
	Frame = parse(FrameText),
	[
	?_assertMatch("value", get_header(Frame, "name")),
	?_assertMatch("bar", get_header(Frame, "foo")),
	?_assertMatch({error, "header doesn't exist: not_exist"}, get_header(Frame, "not_exist"))
	].

parse_headers_test_() ->
	Headers = parse_headers(["name:value", "foo:bar"]),
	[
	?_assertMatch([{"name", "value"}, {"foo", "bar"}], Headers)
	].
	
split_frame_test_() ->
	FrameText = "COMMAND\nname:value\nfoo:bar\n\nmessage body\n\000\n",
	Envelope = lists:nth(1, split_frame(FrameText)),
	[
	?_assertMatch("COMMAND\nname:value\nfoo:bar", Envelope)
	].