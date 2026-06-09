/**
 * Copyright (c) 2023 Cisco Systems, Inc. and its affiliates All rights reserved.
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 */

import { Navbar, Nav, Container, NavDropdown } from "react-bootstrap";
import { toast } from "react-toastify";
import { LinkContainer } from "react-router-bootstrap";
import { useSelector, useDispatch } from "react-redux";
import { useNavigate } from "react-router-dom";
import { useLogoutMutation } from "../slices/usersApiSlice";
import { logout } from "../slices/authSlice";
import "../index.css";

const CustomNavItems = ({ name, link }) => {
  return (
    <Nav.Item>
      <LinkContainer to={link}>
        <Nav.Link className="text-white">
          {name}
        </Nav.Link>
      </LinkContainer>
    </Nav.Item>
  );
};

const Header = () => {
  const { userInfo } = useSelector((state) => state.auth);

  const dispatch = useDispatch();
  const navigate = useNavigate();

  const [logoutApiCall] = useLogoutMutation();

  const logoutHandler = async () => {
    try {
      // const jwtCookie = Cookies.get("jwt");
      // if (!jwtCookie) {
      //   toast.error("No JWT cookie found!");
      // } else {
      //   await logoutApiCall(jwtCookie).unwrap();
      //   dispatch(logout());
      //   toast.success("Logged out", {
      //     className: "toast-container-custom",
      //     autoClose: false,
      //     hideProgressBar: true,
      //     closeOnClick: true,
      //     pauseOnHover: true,
      //     draggable: true,
      //     progress: undefined,
      //     theme: "dark",
      //   });
      await logoutApiCall({email: userInfo.email}).unwrap();
      dispatch(logout());
      toast.success("Logged out", {
        className: "toast-container-custom",
        autoClose: 500,
        hideProgressBar: true,
        closeOnClick: true,
        pauseOnHover: true,
        draggable: true,
        progress: undefined,
        theme: "dark",
      });
      navigate("/login");
    } catch (err) {
      console.error(err);
    }
  };

  return (
    <header>
      <Navbar
        bg="dark"
        variant="dark"
        expand="lg"
        collapseOnSelect
        className="navbar-martian"
      >
        <Container>
          <LinkContainer to="/">
            <Navbar.Brand className="text-white text-uppercase d-flex align-items-center gap-2">
              <img
                src="./src/assets/coin-front.png"
                alt="logo"
                className="navbar-logo"
              />
              <span>
                <strong>Martian </strong>
                <span className="brand-mars-red">Bank</span>
              </span>
            </Navbar.Brand>
          </LinkContainer>
          <Navbar.Toggle aria-controls="martian-navbar-nav" />
          <Navbar.Collapse id="martian-navbar-nav">
            <Nav className="ms-auto align-items-lg-center gap-lg-3">
              {userInfo ? (
                <>
                  <NavDropdown
                    title="Accounts"
                    id="accounts"
                    className="custom-nav-dropdown"
                  >
                    <LinkContainer to="/">
                      <NavDropdown.Item>My Accounts</NavDropdown.Item>
                    </LinkContainer>
                    <LinkContainer to="/new-account">
                      <NavDropdown.Item>New Account</NavDropdown.Item>
                    </LinkContainer>
                  </NavDropdown>
                  <CustomNavItems name="Transfer" link="/transfer" />
                  <CustomNavItems name="Transactions" link="/transactions" />
                  <CustomNavItems name="Loans" link="/loan" />
                  <CustomNavItems name="Find ATMs" link="/find-atm" />
                  <NavDropdown
                    title={userInfo.name}
                    id="username"
                    className="custom-nav-dropdown"
                  >
                    <LinkContainer to="/profile">
                      <NavDropdown.Item>Personal Info</NavDropdown.Item>
                    </LinkContainer>
                    <LinkContainer to="/login">
                      <NavDropdown.Item onClick={logoutHandler}>
                        Logout
                      </NavDropdown.Item>
                    </LinkContainer>
                  </NavDropdown>
                </>
              ) : (
                <>
                  <CustomNavItems name="Find ATMs" link="/find-atm" />
                  <Nav.Item>
                    <LinkContainer to="/register">
                      <Nav.Link className="text-white">Signup</Nav.Link>
                    </LinkContainer>
                  </Nav.Item>
                  <Nav.Item>
                    <LinkContainer to="/login">
                      <Nav.Link className="text-white">Login</Nav.Link>
                    </LinkContainer>
                  </Nav.Item>
                </>
              )}
            </Nav>
          </Navbar.Collapse>
        </Container>
      </Navbar>
    </header>
  );
};

export default Header;
