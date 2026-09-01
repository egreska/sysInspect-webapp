# One InspectionItem form screen owns chrome and persist

Create and edit of an InspectionItem are one screen. That screen owns the create footer, the edit save bar, and the InspectionItemIntake calls. InspectionFormViewModel keeps inspection-row lifecycle only (open a row, finish, abandon if empty). We considered leaving two hosts that embed the shared form and call Intake — create through `addItem` on the ViewModel. Those hosts were pass-through: “how do I persist an InspectionItem?” bounced across four modules. Customer already collapsed Add/Edit the same way. Sequence is assigned at Intake create (next after existing items), not counted on the ViewModel.

**Considered options:** two shallow hosts plus ViewModel `addItem`; keep the create host as an inspection-session wrapper and collapse edit only; one form screen owns chrome and Intake, ViewModel is inspection lifecycle only (chosen).

**Consequences:** Do not restore `InspectionFormViewController` or `InspectionItemEditViewController`. Do not put FormState persist on the ViewModel. Callers present `InspectionItemFormViewController` for create (`viewModel:`) or edit (`inspectionItem:`). The form asks the ViewModel for the Inspection, then Intake creates; edit updates through Intake. Tests hit Intake for persist and sequence, and the ViewModel for identity and abandon — not `addItem`.
