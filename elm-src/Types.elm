module Types exposing (..)

import Dict
import Keyboard
import Http


type Msg
    = EditSingleParameter Parameter SectionID String
    | EditAllParameters Parameter String
    | ChangeBuildMode String
    | Build
    | ProcessModel (Result Http.Error ModellingResults)
    | SetOligomericState String
    | Clear
    | DownloadPdb
    | SetParametersAndBuild ParametersDict
    | KeyMsg Keyboard.KeyCode
    | TogglePanel Panel
    | ExpandHistory HistoryID


type alias SectionID = Int

type alias HistoryID = Int


type alias ParametersDict = Dict.Dict SectionID ParameterRecord


type alias ParameterRecord =
    { radius : Maybe Float
    , pitch : Maybe Float
    , phiCA : Maybe Float
    , sequence : Maybe String
    , register : String
    , superHelRot : Maybe Float
    , antiParallel : Bool
    , zShift : Maybe Float
    }


type alias InputValuesDict = Dict.Dict SectionID InputValues


type alias InputValues =
    { radius : String
    , pitch : String
    , phiCA : String
    , sequence : String
    , register : String
    , superHelRot : String
    , antiParallel : String
    , zShift : String
    }


type alias ModellingResults =
    { pdbFile : String
    , score : Float
    , residuesPerTurn : Float
    }


type Parameter
    = Radius
    | Pitch
    | PhiCA
    | Sequence
    | Register
    | SuperHelicalRotation
    | Orientation
    | ZShift


type BuildMode
    = Basic
    | Advanced


type Panel
    = AppHeaderPanel
    | BuildPanel
    | ExamplesPanel
    | BuildingStatusPanel
    | BuildHistoryPanel


emptyParameterRecord : ParameterRecord
emptyParameterRecord =
    ParameterRecord Nothing Nothing Nothing Nothing "a" Nothing False Nothing


emptyInput : InputValues
emptyInput =
    InputValues "" "" "" "" "a" "" "False" ""