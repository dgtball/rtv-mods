extends RefCounted

## Единственный набор битмасок перерисовки окна. Раньше их было два -
## RefreshScope в VTKUI и локальные R_* в VTKEditor, синхронизированных руками:
## добавленная в один набор область молча не доезжала до второго. VTKUI держит
## прежнее имя RefreshScope алиасом, редактор берёт те же константы отсюда.

const EQUIP := 1
const GEAR := 2
const DONE := 4
const OVERLAY := 8
const LIST := 16
const PREVIEW := 32
const PAGES := EQUIP | GEAR | DONE | OVERLAY
