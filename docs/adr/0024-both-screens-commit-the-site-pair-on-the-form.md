# Both screens commit the site pair on the form

Customer details and the customer form commit SiteRacking and the SiteDocument files onto CustomerFormState together when Done is valid. The sheet edits a copy and does not hand the pair back. Cancel leaves the form unchanged. An invalid profile leaves the form unchanged and Done shows SiteRacking's sentence. CustomerIntake remains the persist. Customer details writes immediately after the commit. The customer form writes the pair when the Customer is saved.

File refusal sentences live on SiteDocumentAcceptance. The profile sentences stay on SiteRacking. At five SiteDocuments, Add stays disabled and there is no sentence. The summary line only reads. Search refresh stays on the screen after CustomerIntake succeeds. Details stays quiet when that write fails. The missing user-id alert stays on customer save. Camera sentences, the unreadable-file sentence, and the duplicate catalog sentence stay on the sheet.

**Considered options:** the sheet returns the pair and each screen saves it; the sheet persists for details; the summary line joins the edit. None of those. One commit onto the form (chosen).

**Consequences:** Screens do not assign the two fields. The sheet does not persist. Do not move the profile sentences onto acceptance. Do not add a five-file sentence. Intake, SiteRacking, and SiteDocument tests stay. New tests cover the form commit and the two file sentences. This refines ADR 0010. Empty profile stays nil, and a document kept by id does not have its bytes rewritten.
