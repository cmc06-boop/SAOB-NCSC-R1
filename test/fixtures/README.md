# Synthetic test fixtures

`python_finance.sqlite` was generated with the original Python project's Database class. It contains development accounts and one synthetic budget record to verify schema/password compatibility. It is not a user's working database and contains no actual agency financial transactions.

`import_sample.xlsx` was generated with openpyxl. It exercises a header on row 8, normal amounts, an uncached formula, a formula with a cached value, a budget line on row 350, a total, and a summary worksheet.
