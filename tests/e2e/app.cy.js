describe("Fullstack App E2E", () => {
  it("loads homepage", () => {
    cy.visit("http://localhost:3000");
    cy.contains("Welcome to the Fullstack App");
  });

  it("navigates to About page", () => {
    cy.visit("http://localhost:3000");
    cy.contains("About").click();
    cy.contains("About This App");
  });
});
