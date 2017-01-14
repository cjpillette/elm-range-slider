module RangeSlider exposing (Model, Settings, AxisTick, StepSize, Msg, activate, view, update, subscriptions)

{-| A slider built natively in Elm

#The base model for the range slider
@docs Model

@docs Settings the settings for the slider

@docs AxisTick represents a single tick along the axis

@docs StepSize How big each step for the slider will be

@docs Msg is the type expected by update

@docs update takes a model and a message and applies it to create an updated model

@docs activate returns everything that is needed to create a range slider

@docs subscriptions the necessary subscriptions to make everything work

@docs view creates a basic html structure for the range slider
-}

import Html exposing (Html, span, div, Attribute)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Mouse exposing (Position)
import Json.Decode as Json
import Css exposing (..)
import CssHooks as CssHooks exposing (..)
import Html.CssHelpers


{ id, class, classList } =
    Html.CssHelpers.withNamespace "rangeSlider"
{-| The base model for the slider
-}
type alias Model =
    { from : Float
    , to : Float
    , min : Float
    , max : Float
    , dragPosition : RangeDrag
    , stepSize : Maybe StepSize
    , formatter : Float -> String
    , scale : Scale
    , height : Float
    , width : Float
    , axisTicks : List AxisTick
    }


{-| Represents a tick that goes along the X axis.
 The value determines where it should go,
 isLabeled determines if the it should have a label below.
 The label is formatted by the formatter.
-}
type alias AxisTick =
    { value : Float
    , isLabeled : Bool
    }


type alias Scale =
    { range : Float
    , scaleValue : Float -> Float
    }


{-| The settings for the range slider
-}
type alias Settings =
    { stepSize : Maybe StepSize
    , formatter : Maybe (Float -> String)
    , from : Maybe Float
    , to : Maybe Float
    , min : Maybe Float
    , max : Maybe Float
    , height : Maybe Float
    , width : Maybe Float
    , axisTicks : Maybe (List AxisTick)
    }


{-| How big each step for the slider will be
-}
type alias StepSize =
    Float


type RangeDrag
    = BeginDrag Drag
    | EndDrag Drag
    | None


type alias Drag =
    { start : Position
    , current : Position
    }


{-| The basic type accepted by the update
-}
type Msg
    = DragStart (Drag -> RangeDrag) Position
    | DragAt Position
    | DragEnd Position


{-| Creates an initial model
-}
initialModel : Settings -> Model
initialModel settings =
    let
        minValue =
            Maybe.withDefault 0.0 settings.min

        maxValue =
            Maybe.withDefault 100.0 settings.max

        percentScale minValue maxValue =
            let
                range =
                    maxValue - minValue
            in
                { range = range
                , scaleValue = (\value -> (value - minValue) / range * 100)
                }

        tickStep =
            Maybe.withDefault 10 settings.stepSize

        defaultTicks =
            List.map ((flip AxisTick) False << ((*) tickStep) << toFloat) <| List.range (Basics.round <| minValue / tickStep) (Basics.round <| maxValue / tickStep)
    in
        { from = Maybe.withDefault 40.0 settings.from
        , to = Maybe.withDefault 60.0 settings.to
        , min = minValue
        , max = maxValue
        , dragPosition = None
        , stepSize = settings.stepSize
        , formatter = Maybe.withDefault (toString) settings.formatter
        , scale = percentScale minValue maxValue
        , height = Maybe.withDefault 75.0 settings.height
        , width = Maybe.withDefault 200.0 settings.width
        , axisTicks = Maybe.withDefault defaultTicks settings.axisTicks
        }


{-| Returns the necessities for initializing a range slider
-}
activate : Settings -> ( Model, Cmd Msg )
activate settings =
    ( initialModel settings, Cmd.none )


{-| Returns the subscriptions necessary to run
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    case model.dragPosition of
        None ->
            Sub.none

        _ ->
            Sub.batch [ Mouse.moves DragAt, Mouse.ups DragEnd ]


{-| takes a model and a message and applies it to create an updated model
-}
update : Model -> Msg -> ( Model, Cmd Msg )
update model msg =
    case msg of
        DragStart createRangeDrag xy ->
            ( { model | dragPosition = createRangeDrag <| Drag xy xy }, Cmd.none )

        DragAt xy ->
            ( { model | dragPosition = updateDrag model.dragPosition xy }, Cmd.none )

        DragEnd _ ->
            ( { model | to = getEndValue model, from = getBeginValue model, dragPosition = None }, Cmd.none )


{-| Displays the range slider
-}
view : Model -> Html Msg
view model =
    let
        barHeight =
            4

        handleDiameter =
            20

        valueRange =
            model.max - model.min

        toValue =
            getEndValue model

        fromValue =
            getBeginValue model

        positionFromValue =
            model.scale.scaleValue >> pct >> left

        styles =
            Css.asPairs >> Html.Attributes.style

        barHighlightWidth =
            Css.width <| pct <| (toValue - fromValue) / valueRange * 100

        handleTop =
            top <| px <| (model.height - handleDiameter) / 2.0

        barTop =
            top <| px <| (model.height - barHeight) / 2.0

        handle value dragCmd =
            span [ onMouseDown dragCmd, styles [ position absolute, positionFromValue value, handleTop ], class [ Handle ] ] []

        backgroundBar =
            span
                [ class [ BackgroundBar ]
                , styles
                    [ position absolute
                    , barTop
                    , left <| px 0
                    ]
                ]
                []

        highlightedBar =
            span [ styles [ position absolute, positionFromValue fromValue, barTop, barHighlightWidth ], class [ BarHighlight ] ] []

        valueDisplay value =
            span [ styles [ position absolute, positionFromValue value ], class [ Value ] ] [ Html.text <| model.formatter value ]

        toTick : AxisTick -> Html a
        toTick tick =
            let
                percent =
                    model.scale.scaleValue tick.value
            in
                span
                    [ styles [ position absolute, left <| pct percent ]
                    , class
                        [ CssHooks.Tick
                        , (if tick.isLabeled then
                            MajorTick
                           else
                            MinorTick
                          )
                        ]
                    ]
                    []

        axis =
            span [ class [ Axis ], styles [ position absolute ] ] <|
                List.map toTick model.axisTicks

        toLabel : Float -> Html a
        toLabel value =
            span
                [ styles [ position absolute, left <| pct <| model.scale.scaleValue value ], class [ AxisLabel ] ]
                [ Html.text <| model.formatter value ]

        axisLabels =
            span [ styles <| [ position absolute, left <| px 0, bottom <| px 0, Css.width <| px model.width, Css.height <| px 9 ] ] <|
                List.map (toLabel << (.value)) <|
                    List.filter (.isLabeled) model.axisTicks
    in
        div [ id Container ]
            [ span [ styles [ display inlineBlock, position relative, Css.width <| px model.width, Css.height <| px model.height ] ]
                [ backgroundBar
                , highlightedBar
                , handle fromValue BeginDrag
                , handle toValue EndDrag
                , valueDisplay fromValue
                , valueDisplay toValue
                , axis
                , axisLabels
                ]
            ]


onMouseDown : (Drag -> RangeDrag) -> Attribute Msg
onMouseDown createRangeDrag =
    on "mousedown" <| Json.map (DragStart createRangeDrag) Mouse.position


updateDrag : RangeDrag -> Position -> RangeDrag
updateDrag rangeDrag position =
    case rangeDrag of
        BeginDrag { start } ->
            BeginDrag <| Drag start position

        EndDrag { start } ->
            EndDrag <| Drag start position

        None ->
            None


getEndValue : Model -> Float
getEndValue model =
    case model.dragPosition of
        None ->
            model.to

        BeginDrag _ ->
            model.to

        EndDrag { start, current } ->
            let
                difference =
                    (toFloat current.x) - (toFloat start.x)

                normalizedDifference =
                    difference * model.scale.range / model.width

                value =
                    valueBySteps model model.to normalizedDifference
            in
                clamp model.from model.max value


valueBySteps : Model -> Float -> Float -> Float
valueBySteps model baseValue normalizedDifference =
    case model.stepSize of
        Just stepSize ->
            stepSize * (toFloat <| Basics.round <| (baseValue + normalizedDifference) / stepSize)

        Nothing ->
            baseValue + normalizedDifference


getBeginValue : Model -> Float
getBeginValue model =
    case model.dragPosition of
        None ->
            model.from

        BeginDrag { start, current } ->
            let
                difference =
                    (toFloat current.x) - (toFloat start.x)

                normalizedDifference =
                    difference * model.scale.range / model.width

                value =
                    valueBySteps model model.from normalizedDifference
            in
                clamp model.min model.to value

        EndDrag _ ->
            model.from
