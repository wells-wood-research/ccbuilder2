module Builder exposing (..)

import BuilderCss exposing (CssClasses(..), cssNamespace, panelStyling)
import BuildPanel
import Css
import Dict
import ExamplesPanel
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.CssHelpers
import Keyboard
import Model exposing (..)
import Ports exposing (..)
import Time
import Types
    exposing
        ( Msg(..)
        , ParameterRecord
        , HistoryID
        , ParametersDict
        , Parameter(..)
        , BuildMode(..)
        , OptStatus(..)
        , Panel(..)
        , Representation
        , RepOption(..)
        , optStatusToString
        , emptyParameterRecord
        )
import Update exposing (update, toCommand)


{ class, classList, id } =
    Html.CssHelpers.withNamespace cssNamespace


styles : List Css.Mixin -> Attribute msg
styles =
    Css.asPairs >> Html.Attributes.style


main : Program (Maybe ExportableModel) Model Msg
main =
    programWithFlags
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


init : Maybe ExportableModel -> ( Model, Cmd Msg )
init storedModel =
    let
        showDefaultModel =
            if storedModel == Nothing then
                True
            else
                False

        model =
            storedModel
                |> Maybe.map exportableToModel
                |> Maybe.withDefault emptyModel
    in
        model
            ! ([ initialiseViewer () ]
                ++ if showDefaultModel then
                    [ toCommand (SetParametersAndBuild ExamplesPanel.basisSetDimer) ]
                   else
                    [ showStructure
                        ( Maybe.withDefault "" model.pdbFile
                        , model.currentRepresentation
                        )
                    ]
              )



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Time.every (5 * Time.second) CheckOptJobs
        , Keyboard.presses KeyMsg
        ]



-- View


view : Model -> Html Msg
view model =
    div [ id "viewer", styles viewerStyling ] [ overlayPanels model ]


viewerStyling : List Css.Mixin
viewerStyling =
    [ Css.position Css.fixed
    , Css.bottom (Css.px 0)
    , Css.top (Css.px 0)
    , Css.left (Css.px 0)
    , Css.right (Css.px 0)
    ]


overlayPanels : Model -> Html Msg
overlayPanels model =
    let
        panelDivs =
            [ siteHeader
            , topLeftToggles
            , topRightToggles
            , BuildPanel.buildPanel
                model.buildMode
                model.parameters
                model.currentInput
                model.building
                model.panelVisibility.buildPanel
            , optimisePanel model.buildMode
                model.optJobs
                model.panelVisibility.optimisePanel
                model.heat
            , ExamplesPanel.examplesPanel model.building model.panelVisibility.examplesPanel
            , statusPanel model.building model.optimising
            , buildHistoryPanel
                model.modelHistory
                model.building
                model.panelVisibility.buildHistoryPanel
            , viewerPanel model.panelVisibility.viewerPanel
            , modelInfoPanel model
            ]
                ++ (List.length model.optJobs
                        |> List.range 1
                        |> List.map2 optJobStatus model.optJobs
                   )
    in
        div [] panelDivs


siteHeader : Html msg
siteHeader =
    div
        [ class [ FlexContainerCss ]
        , id [ AppHeaderPanel ]
        , styles <| headerStyling ++ panelStyling
        ]
        [ header [ styles [ Css.width (Css.pct 50) ] ] [ h1 [] [ text "CCBuilder Mk.2" ] ]
        , div
            [ styles
                [ Css.width (Css.pct 50)
                , Css.textAlign Css.right
                , Css.paddingRight (Css.px 10)
                ]
            ]
            [ h3
                [ styles
                    [ Css.position Css.absolute
                    , Css.right (Css.px 50)
                    ]
                ]
                [ text "Powered by" ]
            , a
                [ href "https://github.com/woolfson-group/isambard" ]
                [ img
                    [ styles
                        [ Css.height (Css.pct 80)
                        , Css.position Css.absolute
                        , Css.top (Css.pct 10)
                        , Css.right (Css.px 3)
                        , Css.borderRadius (Css.px 3)
                        ]
                    , src "static/images/logo_small.png"
                    ]
                    []
                ]
            ]
        ]


headerStyling : List Css.Mixin
headerStyling =
    [ Css.position Css.absolute
    , Css.lineHeight (Css.px 50)
    , Css.top (Css.px 0)
    , Css.left (Css.px 0)
    , Css.width (Css.pct 100)
    ]


topLeftToggles : Html Msg
topLeftToggles =
    div [ styles topLeftTogglesStyling ]
        [ BuildPanel.toggleBuildPanel
        , ExamplesPanel.toggleExamplesPanel
        , toggleOptimisePanel
        ]


topLeftTogglesStyling : List Css.Mixin
topLeftTogglesStyling =
    [ Css.top (Css.px 60)
    , Css.left (Css.px 0)
    , Css.zIndex (Css.int 2)
    , Css.position Css.absolute
    ]


topRightToggles : Html Msg
topRightToggles =
    div [ styles topRightTogglesStyling ]
        [ toggleBuildHistoryPanel
        , toggleViewerPanel
        ]


topRightTogglesStyling : List Css.Mixin
topRightTogglesStyling =
    [ Css.top (Css.px 60)
    , Css.right (Css.px 0)
    , Css.zIndex (Css.int 2)
    , Css.position Css.absolute
    , Css.width (Css.px 30)
    ]



-- Optimise Panel


optimisePanel : BuildMode -> List ( String, OptStatus ) -> Bool -> Int -> Html Msg
optimisePanel buildMode optJobs visible heat =
    let
        advancedBuild =
            case buildMode of
                Basic ->
                    False

                Advanced ->
                    True

        optimising =
            if List.length optJobs > 0 then
                True
            else
                False

        disabledOpt =
            advancedBuild || optimising
    in
        div
            [ class [ OverlayPanelCss ]
            , styles <| panelStyling ++ optimisePanelStyling
            , hidden <| not visible
            ]
            [ h3 [] [ text "Optimise Parameters" ]
            , text "Heat"
            , br [] []
            , input
                [ type_ "range"
                , Html.Attributes.min "0"
                , Html.Attributes.max "2000"
                , value (toString heat)
                , onInput SetHeat
                ]
                []
            , br [] []
            , button
                [ onClick Optimise, disabled disabledOpt ]
                [ text "Optimise Model" ]
            ]


optimisePanelStyling : List Css.Mixin
optimisePanelStyling =
    [ Css.top (Css.px 60)
    , Css.left (Css.px 35)
    ]


toggleOptimisePanel : Html Msg
toggleOptimisePanel =
    div
        [ class [ OverlayPanelCss, LeftPanelToggleCss ]
        , onClick (TogglePanel OptimisePanel)
        ]
        [ text "Optimise" ]



-- Model Info


modelInfoPanel : Model -> Html Msg
modelInfoPanel model =
    div
        [ class [ OverlayPanelCss ]
        , id [ ModelInfoPanel ]
        , styles <| panelStyling ++ modelInfoPanelStyling
        ]
        [ h3 [] [ text "Model Information" ]
        , text "BUDE Energy"
        , br [] []
        , Maybe.map (roundToXDecPlaces 1) model.score
            |> Maybe.map toString
            |> Maybe.withDefault ""
            |> \val -> input [ value val, readonly True ] []
        , br [] []
        , text "Residues per Turn"
        , br [] []
        , Maybe.map (roundToXDecPlaces 2) model.residuesPerTurn
            |> Maybe.map toString
            |> Maybe.withDefault ""
            |> \val -> input [ value val, readonly True ] []
        , br [] []
        , downloadStructureButton model.pdbFile
        ]


modelInfoPanelStyling : List Css.Mixin
modelInfoPanelStyling =
    [ Css.bottom (Css.px 20)
    , Css.left (Css.px 35)
    ]


roundToXDecPlaces : Int -> Float -> Float
roundToXDecPlaces precision num =
    let
        scaling =
            10 ^ precision |> toFloat
    in
        round (num * scaling)
            |> toFloat
            |> flip (/) scaling


downloadStructureButton : Maybe String -> Html Msg
downloadStructureButton pdbFile =
    let
        deactivated =
            if pdbFile == Nothing then
                True
            else
                False
    in
        button
            [ class [ CCBButtonCss ]
            , onClick DownloadPdb
            , disabled deactivated
            ]
            [ text "Download PDB" ]



-- Build History


buildHistoryPanel : Dict.Dict Int ( ParametersDict, Bool, Float ) -> Bool -> Bool -> Html Msg
buildHistoryPanel modelHistory building visible =
    div
        [ class [ OverlayPanelCss ]
        , id [ BuildHistoryPanel ]
        , styles <| panelStyling ++ buildHistoryPanelStyling
        , hidden <| not visible
        ]
        [ h3 [] [ text "Build History" ]
        , table []
            [ modelDetailTableHeader
            , List.map2 modelParametersAsRow
                (Dict.toList modelHistory |> List.reverse)
                (List.repeat (List.length <| Dict.toList modelHistory) building)
                |> List.concat
                |> tbody []
            ]
        ]


modelDetailTableHeader : Html msg
modelDetailTableHeader =
    thead []
        [ tr []
            [ th [] []
            , th [ styles [ Css.width (Css.em 6) ] ] [ text "Radius" ]
            , th [ styles [ Css.width (Css.em 6) ] ] [ text "Pitch" ]
            , th [ styles [ Css.width (Css.em 6) ] ] [ text "Interface Angle" ]
            , th [ styles [ Css.width (Css.em 6) ] ] [ text "Super-Helical Rotation" ]
            , th [ styles [ Css.width (Css.em 6) ] ] [ text "Z-Shift" ]
            , th [] [ text "Sequence" ]
            , th [ styles [ Css.width (Css.em 6) ] ] [ text "Register" ]
            , th [] [ text "BUDE Score" ]
            , th [] []
            ]
        ]


modelParametersAsRow : ( HistoryID, ( ParametersDict, Bool, Float ) ) -> Bool -> List (Html Msg)
modelParametersAsRow ( hID, ( parameters, visible, score ) ) building =
    let
        foldedRows =
            Dict.values parameters
                |> List.tail
                |> Maybe.withDefault []
                |> List.map (modelFoldedRow score)
    in
        if not visible then
            [ modelHistoryTopRow hID parameters building visible score ]
        else
            (modelHistoryTopRow hID parameters building visible score)
                :: foldedRows


modelHistoryTopRow : HistoryID -> ParametersDict -> Bool -> Bool -> Float -> Html Msg
modelHistoryTopRow hID parameters building visible score =
    let
        topRowParameters =
            Dict.values parameters
                |> List.head
                |> Maybe.withDefault emptyParameterRecord
    in
        tr
            []
            ([ div
                [ onClick (ExpandHistory hID) ]
                [ if (not visible) then
                    text "▶"
                  else
                    text "▼"
                ]
             ]
                ++ List.map makeParameterTh
                    (parametersToRow topRowParameters score)
                ++ [ button
                        [ class [ CCBButtonCss ]
                        , onClick (SetParametersAndBuild parameters)
                        , disabled building
                        ]
                        [ text "Rebuild" ]
                   ]
            )


modelFoldedRow : Float -> ParameterRecord -> Html Msg
modelFoldedRow score parameters =
    tr
        []
        ([ text " ┋"
         ]
            ++ List.map makeParameterTh
                (parametersToRow parameters score)
        )


parametersToRow : ParameterRecord -> Float -> List String
parametersToRow parameters score =
    [ parameters.radius
        |> Maybe.withDefault 0
        |> roundToXDecPlaces 1
        |> toString
    , parameters.pitch
        |> Maybe.withDefault 0
        |> round
        |> toString
    , parameters.phiCA
        |> Maybe.withDefault 0
        |> roundToXDecPlaces 1
        |> toString
    , parameters.superHelRot
        |> Maybe.withDefault 0
        |> roundToXDecPlaces 1
        |> toString
    , parameters.zShift
        |> Maybe.withDefault 0
        |> roundToXDecPlaces 1
        |> toString
    , parameters.sequence |> Maybe.withDefault ""
    , parameters.register
    , toString <| roundToXDecPlaces 2 score
    ]


makeParameterTh : String -> Html Msg
makeParameterTh pString =
    text pString
        |> List.singleton
        |> th []


buildHistoryPanelStyling : List Css.Mixin
buildHistoryPanelStyling =
    [ Css.top (Css.px 60)
    , Css.right (Css.px 35)
    ]


toggleBuildHistoryPanel : Html Msg
toggleBuildHistoryPanel =
    div
        [ class [ OverlayPanelCss, RightPanelToggleCss ]
        , onClick (TogglePanel BuildHistoryPanel)
        ]
        [ text "Build History" ]



-- Viewer Panel


viewerPanel : Bool -> Html Msg
viewerPanel visible =
    div
        [ class [ OverlayPanelCss ]
        , id [ ViewerPanel ]
        , styles <| panelStyling ++ viewerPanelStyling
        , hidden <| not visible
        ]
        [ h2 [] [ text "Viewer Options" ]
        , hr [] []
        , h3 [] [ text "Representation" ]
        , hr [] []
        , text "Backbone"
        , br [] []
        , button
            [ class [ CCBButtonCss ]
            , onClick (EditRepresentation Cartoon)
            ]
            [ text "Cartoon" ]
        , button
            [ class [ CCBButtonCss ]
            , onClick (EditRepresentation Trace)
            ]
            [ text "Trace" ]
        , br [] []
        , text "All Atoms"
        , br [] []
        , button
            [ class [ CCBButtonCss ]
            , onClick (EditRepresentation BallsAndSticks)
            ]
            [ text "Balls and Sticks" ]
        , button
            [ class [ CCBButtonCss ]
            , onClick (EditRepresentation Spheres)
            ]
            [ text "Spheres" ]
        , button
            [ class [ CCBButtonCss ]
            , onClick (EditRepresentation Points)
            ]
            [ text "Dots" ]
        , hr [] []
        , h3 [] [ text "Other Options" ]
        , hr [] []
        , button
            [ class [ CCBButtonCss ]
            , onClick ShowAxes
            ]
            [ text "Axes" ]
        , text " (xyz = rgb)"
        ]


viewerPanelStyling : List Css.Mixin
viewerPanelStyling =
    [ Css.top (Css.px 60)
    , Css.right (Css.px 35)
    ]


toggleViewerPanel : Html Msg
toggleViewerPanel =
    div
        [ class [ OverlayPanelCss, RightPanelToggleCss ]
        , onClick (TogglePanel ViewerPanel)
        ]
        [ text "Viewer" ]



-- Building Status


statusPanel : Bool -> Bool -> Html msg
statusPanel building optimising =
    div
        [ class [ OverlayPanelCss ]
        , id [ BuildingStatusPanel ]
        , styles <| buildingStatusStyling ++ panelStyling
        , hidden ((not building) && (not optimising))
        ]
        [ if optimising then
            text "Optimising"
          else
            text "Building"
        , img [ src "static/css/infinity.gif", width 80, height 80 ] []
        ]


buildingStatusStyling : List Css.Mixin
buildingStatusStyling =
    [ Css.top (Css.pct 50)
    , Css.left (Css.pct 50)
    , Css.width (Css.px 80)
    , Css.height (Css.px 80)
    ]



-- Optimisation Job


optJobStatus : ( String, OptStatus ) -> Int -> Html msg
optJobStatus ( optID, status ) position =
    div
        [ class [ OverlayPanelCss ]
        , styles <| optJobStatusStyling position ++ panelStyling
        ]
        [ text optID
        , br [] []
        , text (optStatusToString status)
        ]


optJobStatusStyling : Int -> List Css.Mixin
optJobStatusStyling position =
    [ Css.bottom (Css.px 20)
    , Css.right (Css.px 35)
    ]
